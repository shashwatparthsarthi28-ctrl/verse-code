import 'dart:math';

import 'ludo_engine.dart';

const List<String> kDifficulties = ['easy', 'medium', 'hard'];
const List<String> kPersonas = ['rusher', 'guardian', 'strategist'];

String difficultyLabel(String d) => d.isEmpty ? d : d[0].toUpperCase() + d.substring(1);

String personaLabel(String p) {
  switch (p) {
    case 'rusher':
      return 'Rusher';
    case 'guardian':
      return 'Guardian';
    default:
      return 'Strategist';
  }
}

String personaBlurb(String p) {
  switch (p) {
    case 'rusher':
      return 'Hunts captures and pushes its lead token.';
    case 'guardian':
      return 'Prefers safe squares and avoids danger.';
    default:
      return 'Balances risk, progress and captures.';
  }
}

/// Bot decision making.
/// Easy = random legal move. Medium = persona heuristic with occasional slips.
/// Hard = heuristic plus risk analysis (threat from opponents behind).
class BotBrain {
  static const Map<String, Map<String, double>> weights = {
    'rusher': {'capture': 140, 'home': 70, 'leaveYard': 50, 'enterColumn': 25, 'safe': 15, 'progress': 0.9, 'danger': 15, 'escape': 20},
    'guardian': {'capture': 90, 'home': 80, 'leaveYard': 45, 'enterColumn': 35, 'safe': 45, 'progress': 0.5, 'danger': 45, 'escape': 50},
    'strategist': {'capture': 110, 'home': 80, 'leaveYard': 55, 'enterColumn': 30, 'safe': 30, 'progress': 0.6, 'danger': 30, 'escape': 35},
  };

  /// Number of opponent tokens that could land on [square] with a single roll.
  static int threat(LudoState s, int seat, int square) {
    var n = 0;
    for (var o = 0; o < Rules.seats; o++) {
      if (o == seat) continue;
      for (var t = 0; t < Rules.tokensPerSeat; t++) {
        final p = s.tokens[o][t];
        final a = Rules.absolute(o, p);
        if (a == null) continue;
        final dist = (square - a + Rules.trackLength) % Rules.trackLength;
        if (dist >= 1 && dist <= 6 && p + dist <= Rules.lastTrack) n++;
      }
    }
    return n;
  }

  static double scoreMove(LudoState s, int seat, int token, int dice, String difficulty, String persona) {
    final w = weights[persona] ?? weights['strategist']!;
    final before = s.tokens[seat][token];
    final sim = s.clone();
    final out = sim.applyMove(seat, token, dice);
    var sc = out.captured.length * w['capture']! + out.capturedLoss * 0.8;
    if (out.reachedHome) sc += w['home']!;
    if (before == -1) sc += w['leaveYard']!;
    if (before <= Rules.lastTrack && out.to > Rules.lastTrack && out.to < Rules.home) {
      sc += w['enterColumn']!;
    }
    final abs = Rules.absolute(seat, out.to);
    if (abs != null && Rules.safe.contains(abs)) sc += w['safe']!;
    sc += out.to * w['progress']!;
    if (difficulty == 'hard') {
      if (abs != null && !Rules.safe.contains(abs)) {
        sc -= threat(sim, seat, abs) * w['danger']!;
      }
      final absBefore = Rules.absolute(seat, before);
      if (absBefore != null && !Rules.safe.contains(absBefore) && threat(s, seat, absBefore) > 0) {
        sc += w['escape']!;
      }
    }
    return sc;
  }

  /// Returns the chosen token index, or -1 if there is no legal move.
  static int choose(LudoState s, int seat, int dice, String difficulty, String persona, Random rng) {
    final legal = s.legalTokens(seat, dice);
    if (legal.isEmpty) return -1;
    if (legal.length == 1) return legal.first;
    int pick() => legal[rng.nextInt(legal.length)];
    if (difficulty == 'easy') return pick();
    if (difficulty == 'medium' && rng.nextDouble() < 0.15) return pick();
    var best = legal.first;
    var bestScore = -1e18;
    for (final t in legal) {
      final sc = scoreMove(s, seat, t, dice, difficulty, persona) + rng.nextDouble() * 0.01;
      if (sc > bestScore) {
        bestScore = sc;
        best = t;
      }
    }
    return best;
  }
}
