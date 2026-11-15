'use strict';
/**
 * LUDO X rules engine (server side reference implementation).
 * The Dart engine in lib/engine/ mirrors this file line-for-line.
 *
 * Progress model per token:  -1 = yard, 0..50 = main track (relative to the
 * seat's own start square), 51..55 = home column, 56 = home (finished).
 * Seats run clockwise: 0 Red, 1 Green, 2 Yellow, 3 Blue. Start square of a
 * seat is absolute square seat*13.
 */
const crypto = require('crypto');

const SEATS = 4;
const TOKENS = 4;
const TRACK = 52;
const LAST_TRACK = 50;
const HOME = 56;
// Four start squares + four star squares (start + 8).
const SAFE = new Set([0, 8, 13, 21, 26, 34, 39, 47]);

const absolute = (seat, p) => (p >= 0 && p <= LAST_TRACK ? (seat * 13 + p) % TRACK : null);

function targetProgress(p, dice) {
  if (p === -1) return dice === 6 ? 0 : null;
  const t = p + dice;
  return t > HOME ? null : t;
}

function initialState(firstTurn) {
  return {
    tokens: Array.from({ length: SEATS }, () => new Array(TOKENS).fill(-1)),
    turn: firstTurn,
    dice: null,
    sixes: 0,
    ranking: [],
  };
}

const cloneState = (s) => JSON.parse(JSON.stringify(s));
const seatFinished = (s, seat) => s.tokens[seat].every((p) => p === HOME);

function legalTokens(s, seat, dice) {
  const out = [];
  for (let t = 0; t < TOKENS; t++) {
    if (targetProgress(s.tokens[seat][t], dice) !== null) out.push(t);
  }
  return out;
}

/** Applies a (pre-validated) move. Mutates s. Captures opponents on non-safe squares. */
function applyMove(s, seat, token, dice) {
  const from = s.tokens[seat][token];
  const to = targetProgress(from, dice);
  if (to === null) throw new Error('illegal move');
  s.tokens[seat][token] = to;
  const captured = [];
  let capturedLoss = 0;
  const abs = absolute(seat, to);
  if (abs !== null && !SAFE.has(abs)) {
    for (let o = 0; o < SEATS; o++) {
      if (o === seat) continue;
      for (let t = 0; t < TOKENS; t++) {
        const p = s.tokens[o][t];
        if (absolute(o, p) === abs) {
          captured.push([o, t]);
          capturedLoss += p;
          s.tokens[o][t] = -1;
        }
      }
    }
  }
  return { seat, token, from, to, captured, capturedLoss, reachedHome: to === HOME };
}

function nextSeat(s, from) {
  for (let i = 1; i <= SEATS; i++) {
    const c = (from + i) % SEATS;
    if (!seatFinished(s, c)) return c;
  }
  return from;
}

// ---------------------------------------------------------------- dice
const sha256 = (str) => crypto.createHash('sha256').update(str).digest();
const sha256Hex = (str) => crypto.createHash('sha256').update(str).digest('hex');
const newSeed = () => crypto.randomBytes(32).toString('hex');
const commitmentOf = (seed) => sha256Hex(seed);

/** Deterministic, unbiased (rejection sampled) roll n derived from the seed. */
function rollFromSeed(seed, n) {
  for (let c = 0; ; c++) {
    const h = sha256(`${seed}:${n}:${c}`);
    for (const b of h) if (b < 252) return (b % 6) + 1;
  }
}

// ---------------------------------------------------------------- bots
const WEIGHTS = {
  rusher: { capture: 140, home: 70, leaveYard: 50, enterColumn: 25, safe: 15, progress: 0.9, danger: 15, escape: 20 },
  guardian: { capture: 90, home: 80, leaveYard: 45, enterColumn: 35, safe: 45, progress: 0.5, danger: 45, escape: 50 },
  strategist: { capture: 110, home: 80, leaveYard: 55, enterColumn: 30, safe: 30, progress: 0.6, danger: 30, escape: 35 },
};

function threat(s, seat, square) {
  let n = 0;
  for (let o = 0; o < SEATS; o++) {
    if (o === seat) continue;
    for (let t = 0; t < TOKENS; t++) {
      const p = s.tokens[o][t];
      const a = absolute(o, p);
      if (a === null) continue;
      const dist = (square - a + TRACK) % TRACK;
      if (dist >= 1 && dist <= 6 && p + dist <= LAST_TRACK) n++;
    }
  }
  return n;
}

function scoreMove(s, seat, token, dice, difficulty, persona) {
  const w = WEIGHTS[persona] || WEIGHTS.strategist;
  const before = s.tokens[seat][token];
  const sim = cloneState(s);
  const out = applyMove(sim, seat, token, dice);
  let sc = out.captured.length * w.capture + out.capturedLoss * 0.8;
  if (out.reachedHome) sc += w.home;
  if (before === -1) sc += w.leaveYard;
  if (before <= LAST_TRACK && out.to > LAST_TRACK && out.to < HOME) sc += w.enterColumn;
  const abs = absolute(seat, out.to);
  if (abs !== null && SAFE.has(abs)) sc += w.safe;
  sc += out.to * w.progress;
  if (difficulty === 'hard') {
    if (abs !== null && !SAFE.has(abs)) sc -= threat(sim, seat, abs) * w.danger;
    const absBefore = absolute(seat, before);
    if (absBefore !== null && !SAFE.has(absBefore) && threat(s, seat, absBefore) > 0) sc += w.escape;
  }
  return sc;
}

/** rnd() must return a float in [0,1). Easy = random, Medium = heuristic with slips, Hard = heuristic + risk. */
function chooseToken(s, seat, dice, difficulty, persona, rnd) {
  const legal = legalTokens(s, seat, dice);
  if (legal.length === 0) return -1;
  if (legal.length === 1) return legal[0];
  const pick = () => legal[Math.floor(rnd() * legal.length)];
  if (difficulty === 'easy') return pick();
  if (difficulty === 'medium' && rnd() < 0.15) return pick();
  let best = legal[0];
  let bestScore = -Infinity;
  for (const t of legal) {
    const sc = scoreMove(s, seat, t, dice, difficulty, persona) + rnd() * 0.01;
    if (sc > bestScore) {
      bestScore = sc;
      best = t;
    }
  }
  return best;
}

// ---------------------------------------------------------------- payouts
const r2 = (x) => Math.round((x + Number.EPSILON) * 100) / 100;

function payoutTable(entry, mult) {
  const m = mult || [1.6, 1.2, 0.7, 0];
  const payouts = m.map((x) => r2(entry * x));
  const pool = r2(entry * 4);
  const total = r2(payouts.reduce((a, b) => a + b, 0));
  const margin = r2(pool - total);
  return { payouts, pool, total, margin, marginPct: pool === 0 ? 0 : r2((margin / pool) * 100) };
}

// ---------------------------------------------------------------- board geometry (used by tests / UI mirror)
function buildTrack() {
  const cells = [];
  const run = (r, c, dr, dc, n) => {
    for (let i = 0; i < n; i++) cells.push([r + dr * i, c + dc * i]);
  };
  run(6, 1, 0, 1, 5); // 0-4
  run(5, 6, -1, 0, 6); // 5-10
  run(0, 7, 0, 1, 2); // 11-12
  run(1, 8, 1, 0, 5); // 13-17
  run(6, 9, 0, 1, 6); // 18-23
  run(7, 14, 1, 0, 2); // 24-25
  run(8, 13, 0, -1, 5); // 26-30
  run(9, 8, 1, 0, 6); // 31-36
  run(14, 7, 0, -1, 2); // 37-38
  run(13, 6, -1, 0, 5); // 39-43
  run(8, 5, 0, -1, 6); // 44-49
  run(7, 0, -1, 0, 2); // 50-51
  return cells;
}

module.exports = {
  SEATS, TOKENS, TRACK, LAST_TRACK, HOME, SAFE,
  absolute, targetProgress, initialState, cloneState, seatFinished, legalTokens,
  applyMove, nextSeat, rollFromSeed, newSeed, commitmentOf, sha256Hex,
  chooseToken, threat, payoutTable, r2, buildTrack,
};
