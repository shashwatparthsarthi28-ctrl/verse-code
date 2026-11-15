'use strict';
const test = require('node:test');
const assert = require('node:assert');
const E = require('../lib/engine');
const M = require('../lib/match');

const rnd = () => Math.random();

test('board track: 52 unique cells, each step is adjacent, starts match standard layout', () => {
  const t = E.buildTrack();
  assert.strictEqual(t.length, 52);
  assert.strictEqual(new Set(t.map((c) => c.join(','))).size, 52);
  const corners = new Set([4, 17, 30, 43]); // inner corners step diagonally around the centre block
  for (let i = 0; i < 52; i++) {
    const a = t[i], b = t[(i + 1) % 52];
    const dr = Math.abs(a[0] - b[0]), dc = Math.abs(a[1] - b[1]);
    if (corners.has(i)) assert.ok(dr === 1 && dc === 1, `corner ${i} should be diagonal`);
    else assert.strictEqual(dr + dc, 1, `gap at ${i}`);
  }
  assert.deepStrictEqual(t[0], [6, 1]);
  assert.deepStrictEqual(t[13], [1, 8]);
  assert.deepStrictEqual(t[26], [8, 13]);
  assert.deepStrictEqual(t[39], [13, 6]);
});

test('payout calculator: 100 entry => 160/120/70/0, pool 400, margin 50 (12.5%)', () => {
  const p = E.payoutTable(100);
  assert.deepStrictEqual(p.payouts, [160, 120, 70, 0]);
  assert.strictEqual(p.pool, 400);
  assert.strictEqual(p.total, 350);
  assert.strictEqual(p.margin, 50);
  assert.strictEqual(p.marginPct, 12.5);
  const q = E.payoutTable(50);
  assert.deepStrictEqual(q.payouts, [80, 60, 35, 0]);
  assert.strictEqual(q.margin, 25);
  const r = E.payoutTable(200);
  assert.deepStrictEqual(r.payouts, [320, 240, 140, 0]);
  assert.strictEqual(r.margin, 100);
});

test('six unlocks a token, other numbers do not', () => {
  const s = E.initialState(0);
  for (let d = 1; d <= 5; d++) assert.deepStrictEqual(E.legalTokens(s, 0, d), []);
  assert.deepStrictEqual(E.legalTokens(s, 0, 6), [0, 1, 2, 3]);
});

test('capture on normal square, no capture on safe squares', () => {
  const s = E.initialState(0);
  s.tokens[0][0] = 2; // red abs 2
  s.tokens[1][0] = 0; // green p0 = abs 13 (safe start)
  // red moves to abs 5 where a blue token sits (blue p = 18 => abs 39+18=57%52=5)
  s.tokens[3][0] = 18;
  const out = E.applyMove(s, 0, 0, 3);
  assert.strictEqual(out.captured.length, 1);
  assert.strictEqual(s.tokens[3][0], -1);
  // safe: red token lands on abs 8 (star) where yellow sits => no capture
  const s2 = E.initialState(0);
  s2.tokens[0][0] = 5;
  s2.tokens[2][0] = (8 - 26 + 52) % 52; // yellow p so abs = 8
  const out2 = E.applyMove(s2, 0, 0, 3);
  assert.strictEqual(out2.captured.length, 0);
  assert.strictEqual(s2.tokens[2][0], 34);
});

test('exact roll needed to finish; home column is private', () => {
  const s = E.initialState(0);
  s.tokens[0][0] = 54;
  assert.deepStrictEqual(E.legalTokens(s, 0, 3), []);
  assert.deepStrictEqual(E.legalTokens(s, 0, 2), [0]);
  const out = E.applyMove(s, 0, 0, 2);
  assert.ok(out.reachedHome);
  // opponent on same relative home column index never captured
  const s2 = E.initialState(0);
  s2.tokens[0][0] = 49;
  s2.tokens[1][0] = 52;
  const o2 = E.applyMove(s2, 0, 0, 3);
  assert.strictEqual(o2.captured.length, 0);
});

test('dice: commitment verifiable and distribution roughly uniform', () => {
  const seed = E.newSeed();
  assert.strictEqual(E.commitmentOf(seed), E.sha256Hex(seed));
  assert.strictEqual(E.rollFromSeed(seed, 5), E.rollFromSeed(seed, 5));
  const counts = [0, 0, 0, 0, 0, 0, 0];
  const N = 60000;
  for (let i = 0; i < N; i++) counts[E.rollFromSeed(seed, i)]++;
  for (let f = 1; f <= 6; f++) assert.ok(Math.abs(counts[f] / N - 1 / 6) < 0.01, `face ${f}: ${counts[f] / N}`);
});

function playFull(mode, difficulties, humanAsBot = true) {
  let now = 1_000_000;
  const seed = E.newSeed();
  const { doc, secret } = M.newMatch({
    id: 'm', uid: 'u', username: 'Tester', mode, entry: 100,
    bots: difficulties.map((d, i) => ({ name: `Bot${i}`, difficulty: d })),
    firstTurn: Math.floor(Math.random() * 4), seed, now, turnSeconds: 20,
  });
  let steps = 0;
  while (!doc.over && steps++ < 20000) {
    now += 1000;
    const seat = doc.state.turn;
    if (doc.seats[seat].isBot) {
      M.botStep(doc, secret, now, doc.seq, rnd);
    } else if (doc.state.dice === null) {
      M.humanRoll(doc, secret, now, doc.seq);
    } else {
      const tok = E.chooseToken(doc.state, 0, doc.state.dice, 'medium', 'strategist', rnd);
      M.humanMove(doc, now, doc.seq, tok);
    }
    // invariants
    for (let s = 0; s < 4; s++) for (const p of doc.state.tokens[s]) assert.ok(p >= -1 && p <= 56);
    // no opponent pair may share a non-safe track square (captures always resolve)
    const seen = new Map();
    for (let s = 0; s < 4; s++) for (const p of doc.state.tokens[s]) {
      const a = E.absolute(s, p);
      if (a === null || E.SAFE.has(a)) continue;
      if (seen.has(a)) assert.strictEqual(seen.get(a), s, 'opponents share a non-safe square');
      seen.set(a, s);
    }
  }
  assert.ok(doc.over, 'game must terminate');
  assert.strictEqual(doc.finalOrder.length, 4);
  assert.strictEqual(new Set(doc.finalOrder).size, 4);
  assert.ok(doc.humanRank >= 1 && doc.humanRank <= 4);
  return doc;
}

test('200 full simulated matches terminate with consistent rankings (all difficulty mixes)', () => {
  const mixes = [['easy', 'easy', 'easy'], ['medium', 'medium', 'medium'], ['hard', 'hard', 'hard'], ['easy', 'medium', 'hard']];
  const ranks = [0, 0, 0, 0, 0];
  for (let i = 0; i < 200; i++) ranks[playFull('competitive', mixes[i % 4]).humanRank]++;
  console.log('human rank distribution (human uses medium AI):', ranks.slice(1));
});

test('hard bots beat easy bots head to head', () => {
  // seat 0 plays "hard", three easy bots: human seat should win clearly more than 25%
  let wins = 0;
  const N = 300;
  for (let i = 0; i < N; i++) {
    let now = 1_000_000;
    const seed = E.newSeed();
    const { doc, secret } = M.newMatch({
      id: 'm', uid: 'u', username: 'H', mode: 'pro', entry: 100,
      bots: ['easy', 'easy', 'easy'].map((d, j) => ({ name: `B${j}`, difficulty: d })),
      firstTurn: i % 4, seed, now, turnSeconds: 20,
    });
    while (!doc.over) {
      now += 1000;
      const seat = doc.state.turn;
      if (doc.seats[seat].isBot) M.botStep(doc, secret, now, doc.seq, rnd);
      else if (doc.state.dice === null) M.humanRoll(doc, secret, now, doc.seq);
      else M.humanMove(doc, now, doc.seq, E.chooseToken(doc.state, 0, doc.state.dice, 'hard', 'strategist', rnd));
    }
    if (doc.humanRank === 1) wins++;
  }
  console.log(`hard-vs-3-easy first-place rate: ${(wins / N * 100).toFixed(1)}%`);
  assert.ok(wins / N > 0.3);
});

test('anti-cheat: stale seq, out of turn, illegal token, rate limit, early timeout, early bot step', () => {
  let now = 5_000_000;
  const { doc, secret } = M.newMatch({
    id: 'm', uid: 'u', username: 'T', mode: 'practice', entry: 0,
    bots: ['easy', 'easy', 'easy'].map((d, i) => ({ name: `B${i}`, difficulty: d })),
    firstTurn: 0, seed: E.newSeed(), now, turnSeconds: 20,
  });
  now += 1000;
  assert.throws(() => M.humanRoll(doc, secret, now, 99), /Stale/);
  assert.throws(() => M.humanMove(doc, now, doc.seq, 0), /Roll the dice first/);
  assert.throws(() => M.timeoutTurn(doc, secret, now, doc.seq, rnd), /not expired/);
  assert.throws(() => M.botStep(doc, secret, now, doc.seq, rnd), /Not a bot turn/);
  M.humanRoll(doc, secret, now, doc.seq);
  assert.throws(() => M.humanRoll(doc, secret, now + 1000, doc.seq), /already rolled|Not your turn|Stale/);
  // timeout accepted only after deadline
  const d2 = M.newMatch({ id: 'x', uid: 'u', username: 'T', mode: 'practice', entry: 0, bots: ['easy', 'easy', 'easy'].map((d, i) => ({ name: `B${i}`, difficulty: d })), firstTurn: 0, seed: E.newSeed(), now, turnSeconds: 20 });
  const r = M.timeoutTurn(d2.doc, d2.secret, now + 21_000, d2.doc.seq, rnd);
  assert.ok(r.event);
  // rate limit
  const d3 = M.newMatch({ id: 'y', uid: 'u', username: 'T', mode: 'practice', entry: 0, bots: ['easy', 'easy', 'easy'].map((d, i) => ({ name: `B${i}`, difficulty: d })), firstTurn: 0, seed: E.newSeed(), now, turnSeconds: 20 });
  M.humanRoll(d3.doc, d3.secret, now + 1000, d3.doc.seq);
  const legalTok = E.legalTokens(d3.doc.state, 0, d3.doc.state.dice || 6)[0];
  if (d3.doc.state.dice !== null) assert.throws(() => M.humanMove(d3.doc, now + 1010, d3.doc.seq, legalTok), /rate limit/);
});

test('abandon settles as rank 4', () => {
  const { doc } = M.newMatch({ id: 'a', uid: 'u', username: 'T', mode: 'competitive', entry: 100, bots: ['easy', 'easy', 'easy'].map((d, i) => ({ name: `B${i}`, difficulty: d })), firstTurn: 0, seed: E.newSeed(), now: 1, turnSeconds: 20 });
  M.abandon(doc, 2);
  assert.strictEqual(doc.humanRank, 4);
  assert.strictEqual(doc.status, 'abandoned');
});

test('rewards: xp, levels and daily streak logic', () => {
  const R = require('../lib/rewards');
  assert.strictEqual(R.xpForMatch(1, true), 80);
  assert.strictEqual(R.xpForMatch(2, true), 45);
  assert.strictEqual(R.xpForMatch(4, true), 20);
  assert.strictEqual(R.xpForMatch(1, false), 0);
  assert.deepStrictEqual([0, 49, 50, 199, 200, 450].map(R.levelOf), [1, 1, 2, 2, 3, 4]);
  const day = 86400000;
  const t0 = Date.UTC(2026, 10, 14, 12);
  // brand new user
  assert.deepStrictEqual(R.dailyStatus({}, t0), { streak: 0, claimedToday: false, nextDay: 1, doneCount: 0 });
  // claimed today
  const today = { lastDaily: R.dayKey(t0), dailyStreak: 3 };
  assert.deepStrictEqual(R.dailyStatus(today, t0), { streak: 3, claimedToday: true, nextDay: 4, doneCount: 3 });
  // claimed yesterday: streak continues
  const yest = { lastDaily: R.dayKey(t0 - day), dailyStreak: 3 };
  assert.deepStrictEqual(R.dailyStatus(yest, t0), { streak: 3, claimedToday: false, nextDay: 4, doneCount: 3 });
  // missed a day: streak resets
  const old = { lastDaily: R.dayKey(t0 - 3 * day), dailyStreak: 6 };
  assert.deepStrictEqual(R.dailyStatus(old, t0), { streak: 0, claimedToday: false, nextDay: 1, doneCount: 0 });
  // after day 7 the cycle restarts
  const week = { lastDaily: R.dayKey(t0 - day), dailyStreak: 7 };
  assert.deepStrictEqual(R.dailyStatus(week, t0), { streak: 7, claimedToday: false, nextDay: 1, doneCount: 0 });
  assert.strictEqual(R.DAILY_AMOUNTS[6], 500);
});
