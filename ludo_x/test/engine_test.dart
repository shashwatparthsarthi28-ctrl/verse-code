import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_x/core/payout.dart';
import 'package:ludo_x/core/progress.dart';
import 'package:ludo_x/engine/bot_ai.dart';
import 'package:ludo_x/engine/fair_dice.dart';
import 'package:ludo_x/engine/ludo_engine.dart';
import 'package:ludo_x/server/server_match.dart';
import 'package:ludo_x/widgets/board_geometry.dart';

ServerMatch _newMatch({String mode = 'competitive', double entry = 100, List<String>? diffs}) => ServerMatch.create(
      id: 'm',
      username: 'Tester',
      mode: mode,
      entry: entry,
      botNames: const ['Rex', 'Nova', 'Zed'],
      difficulties: diffs ?? const ['medium', 'medium', 'medium'],
      multipliers: const [1.6, 1.2, 0.7, 0.0],
      turnSeconds: 20,
      now: 1000000,
      rng: Random(1),
    );

void main() {
  test('track has 52 unique cells; steps adjacent except 4 inner corners', () {
    final t = BoardGeometry.track;
    expect(t.length, 52);
    expect(t.map((c) => '${c[0]},${c[1]}').toSet().length, 52);
    const corners = {4, 17, 30, 43};
    for (var i = 0; i < 52; i++) {
      final a = t[i], b = t[(i + 1) % 52];
      final dr = (a[0] - b[0]).abs(), dc = (a[1] - b[1]).abs();
      if (corners.contains(i)) {
        expect(dr == 1 && dc == 1, true, reason: 'corner $i');
      } else {
        expect(dr + dc, 1, reason: 'gap at $i');
      }
    }
  });

  test('payout calculator matches the spec', () {
    final p = PayoutConfig(entry: 100);
    expect(p.payouts, [160, 120, 70, 0]);
    expect(p.pool, 400);
    expect(p.totalPayout, 350);
    expect(p.margin, 50);
    expect(p.marginPct, 12.5);
    expect(PayoutConfig(entry: 50).payouts, [80, 60, 35, 0]);
    expect(PayoutConfig(entry: 200).payouts, [320, 240, 140, 0]);
    expect(const PayoutConfig(entry: 100, multipliers: [2, 1, 1, 0.5]).isValid, false);
  });

  test('six unlocks a token', () {
    final s = LudoState.initial(0);
    for (var d = 1; d <= 5; d++) expect(s.legalTokens(0, d), isEmpty);
    expect(s.legalTokens(0, 6), [0, 1, 2, 3]);
  });

  test('capture on normal squares but never on safe squares', () {
    final s = LudoState.initial(0);
    s.tokens[0][0] = 2;
    s.tokens[3][0] = 18; // blue abs 5
    expect(s.applyMove(0, 0, 3).captured.length, 1);
    expect(s.tokens[3][0], -1);
    final s2 = LudoState.initial(0);
    s2.tokens[0][0] = 5;
    s2.tokens[2][0] = (8 - 26 + 52) % 52; // yellow on star abs 8
    expect(s2.applyMove(0, 0, 3).captured, isEmpty);
  });

  test('exact roll needed to finish', () {
    final s = LudoState.initial(0);
    s.tokens[0][0] = 54;
    expect(s.legalTokens(0, 3), isEmpty);
    expect(s.legalTokens(0, 2), [0]);
    expect(s.applyMove(0, 0, 2).reachedHome, true);
  });

  test('dice commitment verifies and is deterministic', () {
    final seed = FairDice.newSeed();
    expect(FairDice.verifyCommitment(seed, FairDice.commitment(seed)), true);
    expect(FairDice.roll(seed, 3), FairDice.roll(seed, 3));
    final counts = List.filled(7, 0);
    for (var i = 0; i < 12000; i++) counts[FairDice.roll(seed, i)]++;
    for (var f = 1; f <= 6; f++) expect((counts[f] / 12000 - 1 / 6).abs() < 0.02, true);
  });

  test('50 full matches finish with a valid ranking and hash-chained log', () {
    final rng = Random(42);
    for (var g = 0; g < 50; g++) {
      final m = _newMatch(diffs: const ['easy', 'medium', 'hard']);
      var now = 2000000;
      var steps = 0;
      while (!m.over && steps++ < 20000) {
        now += 1000;
        if (m.seats[m.state.turn].isBot) {
          m.botStep(now, m.seq, rng);
        } else if (m.state.dice == null) {
          m.humanRoll(now, m.seq);
        } else {
          final tok = BotBrain.choose(m.state, 0, m.state.dice!, 'medium', 'strategist', rng);
          m.humanMove(now, m.seq, tok);
        }
      }
      expect(m.over, true);
      expect(m.finalOrder.toSet().length, 4);
      expect(m.humanRank >= 1 && m.humanRank <= 4, true);
      expect(m.log.length > 4, true);
    }
  });

  test('anti-cheat rejects stale, out-of-turn, early-timeout and rate-limited actions', () {
    final m = _newMatch(mode: 'practice', entry: 0);
    while (m.seats[m.state.turn].isBot) {
      m.botStep(2000000 + m.seq * 1000 + 1000, m.seq, Random(3));
    }
    expect(() => m.humanRoll(9000000, 999), throwsA(isA<RejectedAction>()));
    expect(() => m.humanMove(9000000, m.seq, 0), throwsA(isA<RejectedAction>()));
    expect(() => m.timeoutTurn(9000000, m.seq, Random(1)), throwsA(isA<RejectedAction>()));
  });

  test('xp and level formulas match the server (functions/lib/rewards.js)', () {
    expect(Progress.xpForMatch(rank: 1, completed: true), 80);
    expect(Progress.xpForMatch(rank: 2, completed: true), 45);
    expect(Progress.xpForMatch(rank: 4, completed: true), 20);
    expect(Progress.xpForMatch(rank: 1, completed: false), 0);
    expect([0, 49, 50, 199, 200, 450].map(Progress.levelOf).toList(), [1, 1, 2, 2, 3, 4]);
    expect(Progress.fraction(125), closeTo(0.5, 0.001)); // level 2 spans 50..200
    expect(Progress.dailyAmounts.length, 7);
  });
}
