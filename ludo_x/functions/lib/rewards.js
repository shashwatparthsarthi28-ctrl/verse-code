'use strict';
/**
 * XP and daily-reward rules (server side). Mirrors lib/core/progress.dart and the
 * daily logic in lib/services/local_backend.dart. XP / levels never touch money;
 * the daily reward is a small simulated demo-coin bonus.
 */
const DAILY_AMOUNTS = [50, 75, 100, 150, 200, 300, 500];
const DAY_MS = 86400000;

const xpForMatch = (rank, completed) => (completed && rank >= 1 && rank <= 4 ? 20 + [60, 25, 10, 0][rank - 1] : 0);
const levelOf = (xp) => Math.floor(Math.sqrt(Math.max(0, xp) / 50)) + 1;

const dayKey = (ms) => new Date(ms).toISOString().slice(0, 10); // UTC day

/** user = { lastDaily: 'YYYY-MM-DD'|null, dailyStreak: number } */
function dailyStatus(user, nowMs) {
  const last = user.lastDaily || null;
  const streak = user.dailyStreak || 0;
  if (last === dayKey(nowMs)) {
    return { streak, claimedToday: true, nextDay: (streak % 7) + 1, doneCount: ((streak - 1) % 7) + 1 };
  }
  const eff = last === dayKey(nowMs - DAY_MS) ? streak : 0;
  return { streak: eff, claimedToday: false, nextDay: (eff % 7) + 1, doneCount: eff % 7 };
}

module.exports = { DAILY_AMOUNTS, xpForMatch, levelOf, dayKey, dailyStatus };
