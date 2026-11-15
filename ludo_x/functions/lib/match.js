'use strict';
/**
 * Authoritative match logic. Pure functions over a plain JSON "match doc" so
 * they can run inside a Firestore transaction (index.js) and be unit tested.
 * Dice are derived from a server-only seed; clients only ever see results.
 */
const E = require('./engine');

const HUMAN = 0;
const MIN_HUMAN_INTERVAL_MS = 150; // anti-cheat: inhumanly fast actions are rejected
const MIN_BOT_INTERVAL_MS = 350; // bots cannot be stepped faster than this
const MAX_VIOLATIONS = 5;

class RejectedAction extends Error {}

const PERSONAS = ['rusher', 'guardian', 'strategist'];

function newMatch({ id, uid, username, mode, entry, bots, firstTurn, seed, now, turnSeconds }) {
  const seats = [{ seat: 0, isBot: false, name: username }];
  bots.forEach((b, i) =>
    seats.push({ seat: i + 1, isBot: true, name: b.name, difficulty: b.difficulty, persona: b.persona || PERSONAS[i % 3] }),
  );
  const doc = {
    id, uid, mode, entry, seats,
    state: E.initialState(firstTurn),
    seq: 0, rollCounter: 0,
    status: 'active', over: false,
    finalOrder: [], humanRank: 0,
    turnMs: turnSeconds * 1000,
    deadlineMs: now + turnSeconds * 1000,
    lastActionMs: 0,
    violations: 0, flagged: false,
    commitment: E.commitmentOf(seed),
    event: null,
    createdMs: now,
  };
  return { doc, secret: { seed }, log: [logEntry(doc, null, now, 'start', `Match started. Dice commitment ${doc.commitment.slice(0, 16)}…`)] };
}

/** Hash-chained log entry: tampering with history breaks every later hash. */
function logEntry(doc, prevHash, now, type, text) {
  doc._logSeq = (doc._logSeq || 0) + 1;
  const base = `${prevHash || doc.commitment}|${doc._logSeq}|${now}|${type}|${text}`;
  const hash = E.sha256Hex(base).slice(0, 16);
  doc._lastHash = hash;
  return { n: doc._logSeq, ts: now, type, text, hash };
}

const seatName = (doc, seat) => doc.seats[seat].name + (doc.seats[seat].isBot ? ' (AI)' : '');

function passTurn(doc, now) {
  const st = doc.state;
  st.turn = E.nextSeat(st, st.turn);
  st.dice = null;
  st.sixes = 0;
  doc.deadlineMs = now + doc.turnMs;
}

function violation(doc, now, text) {
  doc.violations++;
  const entries = [logEntry(doc, doc._lastHash, now, 'violation', text)];
  if (doc.violations >= MAX_VIOLATIONS && !doc.flagged) {
    doc.flagged = true;
    entries.push(logEntry(doc, doc._lastHash, now, 'flag', 'Match flagged for review (repeated invalid actions).'));
  }
  return entries;
}

function guard(doc, now, seq, actor) {
  if (doc.over) throw new RejectedAction('Match is already over');
  if (seq !== doc.seq) throw new RejectedAction('Stale or replayed request');
  const gap = now - doc.lastActionMs;
  if (actor === 'human' && gap < MIN_HUMAN_INTERVAL_MS) throw new RejectedAction('Action rate limit');
  if (actor === 'bot' && gap < MIN_BOT_INTERVAL_MS) throw new RejectedAction('Bot step too early');
}

/** Rolls for the current seat. Returns { event, log }. */
function doRoll(doc, secret, now) {
  const st = doc.state;
  const seat = st.turn;
  const log = [];
  const value = E.rollFromSeed(secret.seed, doc.rollCounter++);
  log.push(logEntry(doc, doc._lastHash, now, 'roll', `${seatName(doc, seat)} rolled ${value} (#${doc.rollCounter})`));
  st.sixes = value === 6 ? st.sixes + 1 : 0;
  if (st.sixes === 3) {
    log.push(logEntry(doc, doc._lastHash, now, 'skip', `${seatName(doc, seat)} rolled three sixes - turn forfeited`));
    passTurn(doc, now);
    return { event: { type: 'roll', seat, value, legal: [], skipped: 'three_sixes' }, log };
  }
  const legal = E.legalTokens(st, seat, value);
  if (legal.length === 0) {
    log.push(logEntry(doc, doc._lastHash, now, 'skip', `${seatName(doc, seat)} has no legal move`));
    passTurn(doc, now);
    return { event: { type: 'roll', seat, value, legal: [], skipped: 'no_moves' }, log };
  }
  st.dice = value;
  return { event: { type: 'roll', seat, value, legal, skipped: null }, log };
}

function finishIfOver(doc, now, log) {
  const st = doc.state;
  const humanDone = st.ranking.includes(HUMAN);
  if (!humanDone && st.ranking.length < 3) return;
  const rest = [0, 1, 2, 3]
    .filter((s) => !st.ranking.includes(s))
    .sort((a, b) => st.tokens[b].reduce((x, y) => x + y, 0) - st.tokens[a].reduce((x, y) => x + y, 0));
  doc.finalOrder = [...st.ranking, ...rest];
  doc.humanRank = doc.finalOrder.indexOf(HUMAN) + 1;
  doc.over = true;
  doc.status = 'completed';
  st.dice = null;
  log.push(logEntry(doc, doc._lastHash, now, 'over', `Match complete. Final order: ${doc.finalOrder.map((s) => seatName(doc, s)).join(' > ')}`));
}

/** Applies the pending dice to a token for the current seat. */
function doMove(doc, token, now) {
  const st = doc.state;
  const seat = st.turn;
  const d = st.dice;
  const log = [];
  if (d === null) throw new RejectedAction('Roll the dice first');
  if (!E.legalTokens(st, seat, d).includes(token)) {
    throw new RejectedAction('Illegal token selection');
  }
  const out = E.applyMove(st, seat, token, d);
  let text = `${seatName(doc, seat)} moved token ${token + 1}: ${out.from} -> ${out.to}`;
  if (out.captured.length) text += ` capturing ${out.captured.length} token(s)`;
  if (out.reachedHome) text += ' and reached home';
  log.push(logEntry(doc, doc._lastHash, now, 'move', text));
  if (E.seatFinished(st, seat) && !st.ranking.includes(seat)) {
    st.ranking.push(seat);
    log.push(logEntry(doc, doc._lastHash, now, 'finish', `${seatName(doc, seat)} finished #${st.ranking.length}`));
  }
  finishIfOver(doc, now, log);
  let extra = false;
  if (!doc.over) {
    extra = (d === 6 || out.captured.length > 0 || out.reachedHome) && !E.seatFinished(st, seat);
    if (extra) {
      st.dice = null;
      doc.deadlineMs = now + doc.turnMs;
    } else passTurn(doc, now);
  }
  return {
    event: { type: 'move', seat, token, from: out.from, to: out.to, captured: out.captured, home: out.reachedHome, extra },
    log,
  };
}

function commit(doc, now, result) {
  doc.seq++;
  doc.lastActionMs = now;
  doc.event = result.event;
  return result;
}

// ---- public actions ---------------------------------------------------------
function humanRoll(doc, secret, now, seq) {
  guard(doc, now, seq, 'human');
  if (doc.state.turn !== HUMAN) throw new RejectedAction('Not your turn');
  if (doc.state.dice !== null) throw new RejectedAction('Dice already rolled');
  return commit(doc, now, doRoll(doc, secret, now));
}

function humanMove(doc, now, seq, token) {
  guard(doc, now, seq, 'human');
  if (doc.state.turn !== HUMAN) throw new RejectedAction('Not your turn');
  return commit(doc, now, doMove(doc, token, now));
}

/** One bot action: roll if no dice pending, otherwise choose and apply a move. */
function botStep(doc, secret, now, seq, rnd) {
  guard(doc, now, seq, 'bot');
  const seat = doc.state.turn;
  const info = doc.seats[seat];
  if (!info.isBot) throw new RejectedAction('Not a bot turn');
  if (doc.state.dice === null) return commit(doc, now, doRoll(doc, secret, now));
  const token = E.chooseToken(doc.state, seat, doc.state.dice, info.difficulty, info.persona, rnd);
  return commit(doc, now, doMove(doc, token, now));
}

/** Server-side turn timer: only honoured once the deadline really passed. */
function timeoutTurn(doc, secret, now, seq, rnd) {
  if (doc.over) throw new RejectedAction('Match is already over');
  if (seq !== doc.seq) throw new RejectedAction('Stale or replayed request');
  if (now < doc.deadlineMs) throw new RejectedAction('Turn timer has not expired');
  const st = doc.state;
  if (doc.seats[st.turn].isBot) throw new RejectedAction('Not a human turn');
  const log = [logEntry(doc, doc._lastHash, now, 'timeout', `${seatName(doc, st.turn)} ran out of time - auto play`)];
  let result;
  if (st.dice === null) {
    result = doRoll(doc, secret, now);
    if (st.turn === HUMAN && st.dice !== null) {
      // auto-move the freshly rolled dice so one timeout resolves the whole turn
      const tok = E.chooseToken(st, HUMAN, st.dice, 'medium', 'strategist', rnd);
      const roll = result;
      const mv = doMove(doc, tok, now);
      result = { event: mv.event, log: [...roll.log, ...mv.log] };
    }
  } else {
    const tok = E.chooseToken(st, HUMAN, st.dice, 'medium', 'strategist', rnd);
    result = doMove(doc, tok, now);
  }
  result.log = [...log, ...result.log];
  return commit(doc, now, result);
}

function abandon(doc, now) {
  if (doc.over) throw new RejectedAction('Match is already over');
  doc.over = true;
  doc.status = 'abandoned';
  doc.humanRank = 4;
  doc.finalOrder = [1, 2, 3, 0];
  doc.seq++;
  return { event: { type: 'abandon' }, log: [logEntry(doc, doc._lastHash, now, 'abandon', 'Player left the match. Entry forfeited (rank 4).')] };
}

function publicView(doc, serverNow) {
  const st = doc.state;
  const legal = st.dice !== null ? E.legalTokens(st, st.turn, st.dice) : [];
  const { _logSeq, _lastHash, ...rest } = doc;
  return { ...rest, legal, serverNowMs: serverNow };
}

module.exports = {
  HUMAN, RejectedAction, PERSONAS, newMatch, humanRoll, humanMove, botStep, timeoutTurn, abandon, publicView,
  MIN_HUMAN_INTERVAL_MS, MIN_BOT_INTERVAL_MS, MAX_VIOLATIONS, violation,
};
