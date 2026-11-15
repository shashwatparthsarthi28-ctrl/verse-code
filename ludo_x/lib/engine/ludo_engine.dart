// LUDO X rules engine. Mirrors functions/lib/engine.js line for line
// (the JS version is covered by unit tests and runs in Cloud Functions).
//
// Progress per token: -1 yard, 0..50 main track (relative to the seat's own
// start square), 51..55 home column, 56 home (finished).
// Seats run clockwise: 0 Red, 1 Green, 2 Yellow, 3 Blue.

class Rules {
  static const int seats = 4;
  static const int tokensPerSeat = 4;
  static const int trackLength = 52;
  static const int lastTrack = 50;
  static const int home = 56;

  /// Four start squares plus four star squares (start + 8).
  static const Set<int> safe = {0, 8, 13, 21, 26, 34, 39, 47};

  static int? absolute(int seat, int progress) {
    if (progress < 0 || progress > lastTrack) return null;
    return (seat * 13 + progress) % trackLength;
  }

  static int? target(int progress, int dice) {
    if (progress == -1) return dice == 6 ? 0 : null;
    final t = progress + dice;
    return t > home ? null : t;
  }
}

class MoveOutcome {
  final int seat;
  final int token;
  final int from;
  final int to;
  final List<List<int>> captured; // [seat, token]
  final int capturedLoss;
  final bool reachedHome;
  const MoveOutcome({
    required this.seat,
    required this.token,
    required this.from,
    required this.to,
    required this.captured,
    required this.capturedLoss,
    required this.reachedHome,
  });
}

class LudoState {
  List<List<int>> tokens;
  int turn;
  int? dice;
  int sixes;
  List<int> ranking;

  LudoState({
    required this.tokens,
    required this.turn,
    this.dice,
    this.sixes = 0,
    List<int>? ranking,
  }) : ranking = ranking ?? <int>[];

  factory LudoState.initial(int firstTurn) {
    return LudoState(
      tokens: List.generate(Rules.seats, (_) => List<int>.filled(Rules.tokensPerSeat, -1)),
      turn: firstTurn,
    );
  }

  LudoState clone() => LudoState(
        tokens: tokens.map((r) => List<int>.from(r)).toList(),
        turn: turn,
        dice: dice,
        sixes: sixes,
        ranking: List<int>.from(ranking),
      );

  bool seatFinished(int seat) => tokens[seat].every((p) => p == Rules.home);

  List<int> legalTokens(int seat, int d) {
    final out = <int>[];
    for (var t = 0; t < Rules.tokensPerSeat; t++) {
      if (Rules.target(tokens[seat][t], d) != null) out.add(t);
    }
    return out;
  }

  /// Applies a pre-validated move. Captures opponents on non-safe squares.
  MoveOutcome applyMove(int seat, int token, int d) {
    final from = tokens[seat][token];
    final to = Rules.target(from, d);
    if (to == null) throw StateError('illegal move');
    tokens[seat][token] = to;
    final captured = <List<int>>[];
    var loss = 0;
    final abs = Rules.absolute(seat, to);
    if (abs != null && !Rules.safe.contains(abs)) {
      for (var o = 0; o < Rules.seats; o++) {
        if (o == seat) continue;
        for (var t = 0; t < Rules.tokensPerSeat; t++) {
          final p = tokens[o][t];
          if (Rules.absolute(o, p) == abs) {
            captured.add([o, t]);
            loss += p;
            tokens[o][t] = -1;
          }
        }
      }
    }
    return MoveOutcome(
      seat: seat,
      token: token,
      from: from,
      to: to,
      captured: captured,
      capturedLoss: loss,
      reachedHome: to == Rules.home,
    );
  }

  int nextSeat(int from) {
    for (var i = 1; i <= Rules.seats; i++) {
      final c = (from + i) % Rules.seats;
      if (!seatFinished(c)) return c;
    }
    return from;
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens,
        'turn': turn,
        'dice': dice,
        'sixes': sixes,
        'ranking': ranking,
      };

  factory LudoState.fromJson(Map<dynamic, dynamic> j) {
    final rows = (j['tokens'] as List)
        .map((r) => (r as List).map((e) => (e as num).toInt()).toList())
        .toList();
    return LudoState(
      tokens: rows,
      turn: (j['turn'] as num).toInt(),
      dice: j['dice'] == null ? null : (j['dice'] as num).toInt(),
      sixes: ((j['sixes'] ?? 0) as num).toInt(),
      ranking: ((j['ranking'] ?? []) as List).map((e) => (e as num).toInt()).toList(),
    );
  }
}
