'use strict';
/**
 * LUDO X - Cloud Functions (v2 callables).
 *
 * SIMULATED MONEY ONLY. There is no payment SDK, no payment provider and no
 * code path that moves real funds. All balances are demo balances that only
 * these functions may write (see firestore.rules: clients have read-only access).
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');
const E = require('./lib/engine');
const M = require('./lib/match');
const R = require('./lib/rewards');

initializeApp();
const db = getFirestore();

const DEFAULT_CONFIG = {
  competitiveEntry: 100,
  proTiers: [50, 100, 200],
  multipliers: [1.6, 1.2, 0.7, 0],
  turnSeconds: 20,
  botThinkMs: 900,
  competitiveBotDifficulty: 'medium',
  botNames: ['Rex', 'Nova', 'Zed'],
  maxDemoDeposit: 10000,
  maxBalance: 100000,
  starterBalance: 1000,
  realPaymentsEnabled: false, // must stay false until legal review is complete
};
const DIFFS = ['easy', 'medium', 'hard'];
const rnd = () => crypto.randomInt(0, 1e9) / 1e9;

const wrap = (fn) => onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  try {
    return await fn(req.auth.uid, req.data || {}, req);
  } catch (e) {
    if (e instanceof M.RejectedAction) throw new HttpsError('failed-precondition', e.message);
    throw e;
  }
});

async function loadConfig(tx) {
  const snap = await (tx || db).collection('config').doc('game').get();
  return { ...DEFAULT_CONFIG, ...(snap.exists ? snap.data() : {}) };
}

const userRef = (uid) => db.collection('users').doc(uid);
const statsRef = () => db.collection('stats').doc('global');

/** Appends an immutable ledger row and returns the new balance. Caller must have read the user doc. */
function ledger(tx, uid, user, type, amount, note, extra) {
  const balance = E.r2((user.balance || 0) + amount);
  if (balance < 0) throw new HttpsError('failed-precondition', 'Insufficient demo balance');
  tx.set(userRef(uid).collection('transactions').doc(), {
    type, amount: E.r2(amount), balanceAfter: balance, note, ts: Date.now(), ...(extra || {}),
  });
  user.balance = balance;
  return balance;
}

function notify(tx, uid, title, body) {
  tx.set(userRef(uid).collection('notifications').doc(), { title, body, ts: Date.now(), read: false });
}

async function ensureUser(tx, uid, req) {
  const ref = userRef(uid);
  const snap = await tx.get(ref);
  if (snap.exists) return { ref, user: snap.data(), created: false };
  const cfg = await loadConfig(tx);
  const name = (req.auth.token.name || req.auth.token.email || 'Player').split('@')[0].slice(0, 16);
  const user = {
    username: name, avatar: 0, played: 0, wins: 0, losses: 0, earnings: 0, balance: 0, xp: 0,
    lastDaily: null, dailyStreak: 0,
    createdAt: Date.now(), activeMatchId: null, isAdmin: !!req.auth.token.admin,
  };
  return { ref, user, created: true, cfg };
}

exports.ensureProfile = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const uid = req.auth.uid;
  await db.runTransaction(async (tx) => {
    const { ref, user, created, cfg } = await ensureUser(tx, uid, req);
    if (!created) return;
    ledger(tx, uid, user, 'bonus', cfg.starterBalance, 'Welcome demo balance (simulated)');
    tx.set(ref, user);
    tx.set(db.collection('leaderboard').doc(uid), { username: user.username, avatar: 0, wins: 0, earnings: 0 });
    tx.set(statsRef(), { users: FieldValue.increment(1) }, { merge: true });
    notify(tx, uid, 'Welcome to LUDO X', 'Your simulated wallet is funded. No real money is ever used.');
  });
  return { ok: true };
});

exports.updateProfile = wrap(async (uid, data) => {
  const username = String(data.username || '').trim().slice(0, 16);
  if (username.length < 3) throw new HttpsError('invalid-argument', 'Username must be 3-16 characters');
  const avatar = Math.max(0, Math.min(11, parseInt(data.avatar || 0, 10)));
  await db.runTransaction(async (tx) => {
    tx.update(userRef(uid), { username, avatar });
    tx.set(db.collection('leaderboard').doc(uid), { username, avatar }, { merge: true });
  });
  return { ok: true };
});

exports.demoDeposit = wrap(async (uid, data) => {
  const amount = E.r2(Number(data.amount));
  await db.runTransaction(async (tx) => {
    const cfg = await loadConfig(tx);
    if (cfg.realPaymentsEnabled) throw new HttpsError('failed-precondition', 'Real payments are not supported');
    if (!(amount > 0) || amount > cfg.maxDemoDeposit) throw new HttpsError('invalid-argument', `Demo deposit must be 1-${cfg.maxDemoDeposit}`);
    const snap = await tx.get(userRef(uid));
    const user = snap.data();
    if (user.balance + amount > cfg.maxBalance) throw new HttpsError('failed-precondition', 'Demo balance limit reached');
    ledger(tx, uid, user, 'deposit', amount, 'Demo deposit (simulated - no real money)');
    tx.update(userRef(uid), { balance: user.balance });
  });
  return { ok: true };
});

exports.requestWithdrawal = wrap(async (uid, data) => {
  const amount = E.r2(Number(data.amount));
  await db.runTransaction(async (tx) => {
    const cfg = await loadConfig(tx);
    if (cfg.realPaymentsEnabled) throw new HttpsError('failed-precondition', 'Real payments are not supported');
    if (!(amount > 0)) throw new HttpsError('invalid-argument', 'Enter an amount');
    const snap = await tx.get(userRef(uid));
    const user = snap.data();
    ledger(tx, uid, user, 'withdrawal', -amount, 'Simulated withdrawal request (no real payout)', { status: 'pending' });
    tx.update(userRef(uid), { balance: user.balance });
    notify(tx, uid, 'Withdrawal request received', `Simulated withdrawal of ${amount} is pending. Nothing is paid out.`);
  });
  return { ok: true };
});

// ------------------------------------------------------------------ daily reward
exports.dailyStatus = wrap(async (uid) => {
  const snap = await userRef(uid).get();
  return R.dailyStatus(snap.data() || {}, Date.now());
});

exports.claimDaily = wrap(async (uid) => {
  let amount = 0;
  await db.runTransaction(async (tx) => {
    const cfg = await loadConfig(tx);
    const snap = await tx.get(userRef(uid));
    const user = snap.data();
    const now = Date.now();
    const st = R.dailyStatus(user, now);
    if (st.claimedToday) throw new HttpsError('failed-precondition', 'Already claimed today. Come back tomorrow!');
    amount = R.DAILY_AMOUNTS[st.nextDay - 1];
    if (user.balance + amount > cfg.maxBalance) throw new HttpsError('failed-precondition', 'Demo balance limit reached');
    ledger(tx, uid, user, 'bonus', amount, `Daily reward - day ${st.nextDay} (simulated)`);
    tx.update(userRef(uid), { balance: user.balance, lastDaily: R.dayKey(now), dailyStreak: st.streak + 1 });
    notify(tx, uid, 'Daily reward claimed', `+${amount} demo coins. Streak: ${st.streak + 1} day(s).`);
  });
  return { amount };
});

// ------------------------------------------------------------------ matches
function matchView(doc, secretRevealed) {
  const v = M.publicView(doc, Date.now());
  if (doc.over) v.revealedSeed = secretRevealed;
  return v;
}

exports.createMatch = wrap(async (uid, data, req) => {
  const mode = data.mode;
  if (!['practice', 'competitive', 'pro'].includes(mode)) throw new HttpsError('invalid-argument', 'Unknown mode');
  return db.runTransaction(async (tx) => {
    const cfg = await loadConfig(tx);
    const { ref, user } = await ensureUser(tx, uid, req);
    if (user.activeMatchId) {
      const existing = await tx.get(db.collection('matches').doc(user.activeMatchId));
      if (existing.exists && !existing.data().over) return { ...M.publicView(existing.data(), Date.now()), resumed: true };
    }
    let entry = 0;
    let diffs = [data.difficulty || 'medium', data.difficulty || 'medium', data.difficulty || 'medium'];
    if (mode === 'competitive') {
      entry = cfg.competitiveEntry;
      diffs = [cfg.competitiveBotDifficulty, cfg.competitiveBotDifficulty, cfg.competitiveBotDifficulty];
    } else if (mode === 'pro') {
      entry = Number(data.entry);
      if (!cfg.proTiers.includes(entry)) throw new HttpsError('invalid-argument', 'Invalid entry tier');
      diffs = Array.isArray(data.difficulties) ? data.difficulties.slice(0, 3) : diffs;
    }
    if (diffs.length !== 3 || !diffs.every((d) => DIFFS.includes(d))) throw new HttpsError('invalid-argument', 'Invalid bot difficulty');
    const id = crypto.randomUUID();
    const seed = E.newSeed();
    const { doc, secret, log } = M.newMatch({
      id, uid, username: user.username, mode, entry,
      bots: diffs.map((d, i) => ({ name: cfg.botNames[i] || `Bot${i + 1}`, difficulty: d })),
      firstTurn: crypto.randomInt(0, 4), seed, now: Date.now(), turnSeconds: cfg.turnSeconds,
    });
    doc.multipliers = cfg.multipliers;
    if (entry > 0) {
      ledger(tx, uid, user, 'entry', -entry, `${mode === 'pro' ? 'Pro Bot Challenge' : 'Competitive Demo'} entry (simulated)`, { matchId: id });
    }
    tx.set(ref, { ...user, activeMatchId: id });
    tx.set(db.collection('matches').doc(id), doc);
    tx.set(db.collection('matchSecrets').doc(id), secret);
    log.forEach((l) => tx.set(db.collection('matches').doc(id).collection('log').doc(String(l.n).padStart(6, '0')), l));
    tx.set(statsRef(), {
      matches: FieldValue.increment(1),
      entries: FieldValue.increment(entry > 0 ? entry * 4 : 0), // pool incl. 3 AI demo entries
    }, { merge: true });
    return M.publicView(doc, Date.now());
  });
});

/** Shared transaction wrapper for all in-match actions. */
function matchAction(applyFn) {
  return wrap(async (uid, data) => {
    const out = await runMatchTx(uid, data, applyFn);
    // Rejections are returned (not thrown) from inside the transaction so the
    // violation log commits; the error is raised here, after the commit.
    if (out && out.__rejected) throw new HttpsError('failed-precondition', out.__rejected);
    return out;
  });
}

function runMatchTx(uid, data, applyFn) {
  return db.runTransaction(async (tx) => {
    const mRef = db.collection('matches').doc(String(data.matchId));
    const sRef = db.collection('matchSecrets').doc(String(data.matchId));
    const [mSnap, sSnap, uSnap] = await Promise.all([tx.get(mRef), tx.get(sRef), tx.get(userRef(uid))]);
    if (!mSnap.exists) throw new HttpsError('not-found', 'Match not found');
    const doc = mSnap.data();
    if (doc.uid !== uid) throw new HttpsError('permission-denied', 'Not your match');
    const secret = sSnap.data();
    const user = uSnap.data();
    const wasOver = doc.over;
    let result;
    try {
      result = applyFn(doc, secret, Date.now(), Number(data.seq), data);
    } catch (e) {
      if (e instanceof M.RejectedAction && !wasOver) {
        const logs = M.violation(doc, Date.now(), `Rejected: ${e.message}`);
        tx.set(mRef, doc);
        logs.forEach((l) => tx.set(mRef.collection('log').doc(`v${l.ts}_${l.n}`), l));
        return { __rejected: e.message };
      }
      throw e;
    }
    result.log.forEach((l) => tx.set(mRef.collection('log').doc(String(l.n).padStart(6, '0')), l));
    if (!wasOver && doc.over) await settle(tx, uid, user, doc);
    tx.set(mRef, doc);
    return matchView(doc, secret.seed);
  });
}

async function settle(tx, uid, user, doc) {
  const rank = doc.humanRank;
  const paid = doc.entry > 0;
  const table = E.payoutTable(doc.entry, doc.multipliers);
  const payout = paid && doc.status === 'completed' ? table.payouts[rank - 1] : 0;
  doc.payout = payout;
  if (payout > 0) ledger(tx, uid, user, 'reward', payout, `Rank ${rank} reward (simulated)`, { matchId: doc.id });
  const net = paid ? E.r2(payout - doc.entry) : 0;
  const update = { balance: user.balance, activeMatchId: null, xp: FieldValue.increment(R.xpForMatch(rank, doc.status === 'completed')) };
  if (paid) {
    update.played = FieldValue.increment(1);
    update.earnings = FieldValue.increment(net);
    if (rank === 1) update.wins = FieldValue.increment(1);
    else update.losses = FieldValue.increment(1);
  }
  tx.update(userRef(uid), update);
  tx.set(userRef(uid).collection('matches').doc(doc.id), {
    mode: doc.mode, entry: doc.entry, rank, payout, ts: Date.now(), completed: doc.status === 'completed',
    difficulty: doc.seats.filter((s) => s.isBot).map((s) => s.difficulty).join('/'),
  });
  if (paid) {
    tx.set(db.collection('leaderboard').doc(uid), {
      username: user.username, wins: FieldValue.increment(rank === 1 ? 1 : 0), earnings: FieldValue.increment(net),
    }, { merge: true });
  }
  tx.set(statsRef(), {
    completed: FieldValue.increment(doc.status === 'completed' ? 1 : 0),
    payouts: FieldValue.increment(payout),
  }, { merge: true });
  notify(tx, uid, doc.status === 'completed' ? `Match finished: rank ${rank}` : 'Match abandoned',
    paid ? `Simulated payout ${payout} (entry ${doc.entry}).` : 'Practice match - no wallet changes.');
}

exports.rollDice = matchAction((doc, secret, now, seq) => M.humanRoll(doc, secret, now, seq));
exports.moveToken = matchAction((doc, secret, now, seq, data) => M.humanMove(doc, now, seq, parseInt(data.token, 10)));
exports.botStep = matchAction((doc, secret, now, seq) => M.botStep(doc, secret, now, seq, rnd));
exports.timeoutTurn = matchAction((doc, secret, now, seq) => M.timeoutTurn(doc, secret, now, seq, rnd));
exports.abandonMatch = matchAction((doc, secret, now) => M.abandon(doc, now));
exports.getMatch = wrap(async (uid, data) => {
  const [m, s] = await Promise.all([
    db.collection('matches').doc(String(data.matchId)).get(),
    db.collection('matchSecrets').doc(String(data.matchId)).get(),
  ]);
  if (!m.exists || m.data().uid !== uid) throw new HttpsError('not-found', 'Match not found');
  return matchView(m.data(), s.data().seed);
});

// ------------------------------------------------------------------ admin
const requireAdmin = (req) => {
  if (!req.auth || !req.auth.token.admin) throw new HttpsError('permission-denied', 'Admin only');
};

exports.adminStats = onCall(async (req) => {
  requireAdmin(req);
  const s = (await statsRef().get()).data() || {};
  const users = s.users || 0, matches = s.matches || 0, completed = s.completed || 0;
  const entries = E.r2(s.entries || 0), payouts = E.r2(s.payouts || 0);
  return {
    users, matches, completed,
    completionRate: matches ? E.r2((completed / matches) * 100) : 0,
    entries, payouts, margin: E.r2(entries - payouts),
    marginPct: entries ? E.r2(((entries - payouts) / entries) * 100) : 0,
    config: await loadConfig(),
  };
});

exports.adminSetConfig = onCall(async (req) => {
  requireAdmin(req);
  const c = req.data || {};
  const next = {};
  if (c.competitiveEntry != null) next.competitiveEntry = Math.max(1, Number(c.competitiveEntry));
  if (Array.isArray(c.proTiers)) next.proTiers = c.proTiers.map(Number).filter((x) => x > 0).slice(0, 6);
  if (Array.isArray(c.multipliers) && c.multipliers.length === 4) next.multipliers = c.multipliers.map((x) => Math.max(0, Number(x)));
  if (c.turnSeconds != null) next.turnSeconds = Math.max(5, Math.min(120, parseInt(c.turnSeconds, 10)));
  if (DIFFS.includes(c.competitiveBotDifficulty)) next.competitiveBotDifficulty = c.competitiveBotDifficulty;
  if (Array.isArray(c.botNames) && c.botNames.length === 3) next.botNames = c.botNames.map((n) => String(n).slice(0, 12));
  next.realPaymentsEnabled = false; // cannot be switched on from the app
  await db.collection('config').doc('game').set(next, { merge: true });
  return { ok: true };
});
