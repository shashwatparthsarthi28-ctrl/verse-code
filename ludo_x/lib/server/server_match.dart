import 'dart:math';

import '../engine/bot_ai.dart';
import '../engine/fair_dice.dart';
import '../engine/ludo_engine.dart';
import '../services/models.dart';

/// Thrown when the "server" refuses an action (anti-cheat / rules).
class RejectedAction implements Exception {
  final String message;
  RejectedAction(this.message);
  @override
  String toString() => message;
}

/// Authoritative match logic. This is the in-process stand-in for the Cloud
/// Functions in functions/lib/match.js (same rules, same anti-cheat checks).
/// The UI never rolls dice or mutates state: it only sends intents
/// (roll / move / botStep / timeout) and renders the snapshot it gets back.
class ServerMatch {
  static const int human = 0;
  static const int minHumanIntervalMs = 150;
  static const int minBotIntervalMs = 350;
  static const int maxViolations = 5;

  final String id;
  final String mode;
  final double entry;
  final List<SeatInfo> seats;
  final LudoState state;
  final String _seed; // never leaves this class until the match is over
  final String commitment;
  final int turnMs;
  final List<double> multipliers;

  int seq = 0;
  int rollCounter = 0;
  String status = 'active';
  bool over = false;
  List<int> finalOrder = [];
  int humanRank = 0;
  int deadlineMs;
  int lastActionMs = 0;
  int violations = 0;
  bool flagged = false;
  double payout = 0;
  Map<String, dynamic>? event;
  final List<LogEntry> log = [];
  String? _lastHash;
  int _logSeq = 0;

  ServerMatch._({
    required this.id,
    required this.mode,
    required this.entry,
    required this.seats,
    required this.state,
    required String seed,
    required this.commitment,
    required this.turnMs,
    required this.deadlineMs,
    required this.multipliers,
  }) : _seed = seed;

  factory ServerMatch.create({
    required String id,
    required String username,
    required String mode,
    required double entry,
    required List<String> botNames,
    required List<String> difficulties,
    required List<double> multipliers,
    required int turnSeconds,
    required int now,
    Random? rng,
  }) {
    final r = rng ?? Random.secure();
    final seats = <SeatInfo>[SeatInfo(seat: 0, isBot: false, name: username)];
    for (var i = 0; i < 3; i++) {
      seats.add(SeatInfo(
        seat: i + 1,
        isBot: true,
        name: i < botNames.length ? botNames[i] : 'Bot${i + 1}',
        difficulty: difficulties[i],
        persona: kPersonas[i % kPersonas.length],
      ));
    }
    final seed = FairDice.newSeed();
    final m = ServerMatch._(
      id: id,
      mode: mode,
      entry: entry,
      seats: seats,
      state: LudoState.initial(r.nextInt(4)),
      seed: seed,
      commitment: FairDice.commitment(seed),
      turnMs: turnSeconds * 1000,
      deadlineMs: now + turnSeconds * 1000,
      multipliers: multipliers,
    );
    m._addLog(now, 'start', 'Match started. Dice commitment ${m.commitment.substring(0, 16)}…');
    return m;
  }

  // ------------------------------------------------------------ logging
  void _addLog(int now, String type, String text) {
    _logSeq++;
    final base = '${_lastHash ?? commitment}|$_logSeq|$now|$type|$text';
    final hash = FairDice.sha256Hex(base).substring(0, 16);
    _lastHash = hash;
    log.add(LogEntry(n: _logSeq, ts: now, type: type, text: text, hash: hash));
  }

  String _name(int seat) => seats[seat].displayName;

  // ------------------------------------------------------------ helpers
  void _passTurn(int now) {
    state.turn = state.nextSeat(state.turn);
    state.dice = null;
    state.sixes = 0;
    deadlineMs = now + turnMs;
  }

  void _guard(int now, int givenSeq, String actor) {
    if (over) throw RejectedAction('Match is already over');
    if (givenSeq != seq) throw RejectedAction('Stale or replayed request');
    final gap = now - lastActionMs;
    if (actor == 'human' && gap < minHumanIntervalMs) throw RejectedAction('Action rate limit');
    if (actor == 'bot' && gap < minBotIntervalMs) throw RejectedAction('Bot step too early');
  }

  /// Records an invalid attempt (called by the backend when an action is rejected).
  void recordViolation(int now, String why) {
    if (over) return;
    violations++;
    _addLog(now, 'violation', 'Rejected: $why');
    if (violations >= maxViolations && !flagged) {
      flagged = true;
      _addLog(now, 'flag', 'Match flagged for review (repeated invalid actions).');
    }
  }

  Map<String, dynamic> _doRoll(int now) {
    final seat = state.turn;
    final value = FairDice.roll(_seed, rollCounter++);
    _addLog(now, 'roll', '${_name(seat)} rolled $value (#$rollCounter)');
    state.sixes = value == 6 ? state.sixes + 1 : 0;
    if (state.sixes == 3) {
      _addLog(now, 'skip', '${_name(seat)} rolled three sixes - turn forfeited');
      _passTurn(now);
      return {'type': 'roll', 'seat': seat, 'value': value, 'legal': <int>[], 'skipped': 'three_sixes'};
    }
    final legal = state.legalTokens(seat, value);
    if (legal.isEmpty) {
      _addLog(now, 'skip', '${_name(seat)} has no legal move');
      _passTurn(now);
      return {'type': 'roll', 'seat': seat, 'value': value, 'legal': <int>[], 'skipped': 'no_moves'};
    }
    state.dice = value;
    return {'type': 'roll', 'seat': seat, 'value': value, 'legal': legal, 'skipped': null};
  }

  void _finishIfOver(int now) {
    final humanDone = state.ranking.contains(human);
    if (!humanDone && state.ranking.length < 3) return;
    final rest = [0, 1, 2, 3].where((s) => !state.ranking.contains(s)).toList()
      ..sort((a, b) => state.tokens[b].fold(0, (x, y) => x + y).compareTo(state.tokens[a].fold(0, (x, y) => x + y)));
    finalOrder = [...state.ranking, ...rest];
    humanRank = finalOrder.indexOf(human) + 1;
    over = true;
    status = 'completed';
    state.dice = null;
    _addLog(now, 'over', 'Match complete. Final order: ${finalOrder.map(_name).join(' > ')}');
  }

  Map<String, dynamic> _doMove(int token, int now) {
    final seat = state.turn;
    final d = state.dice;
    if (d == null) throw RejectedAction('Roll the dice first');
    if (!state.legalTokens(seat, d).contains(token)) throw RejectedAction('Illegal token selection');
    final out = state.applyMove(seat, token, d);
    var text = '${_name(seat)} moved token ${token + 1}: ${out.from} -> ${out.to}';
    if (out.captured.isNotEmpty) text += ' capturing ${out.captured.length} token(s)';
    if (out.reachedHome) text += ' and reached home';
    _addLog(now, 'move', text);
    if (state.seatFinished(seat) && !state.ranking.contains(seat)) {
      state.ranking.add(seat);
      _addLog(now, 'finish', '${_name(seat)} finished #${state.ranking.length}');
    }
    _finishIfOver(now);
    var extra = false;
    if (!over) {
      extra = (d == 6 || out.captured.isNotEmpty || out.reachedHome) && !state.seatFinished(seat);
      if (extra) {
        state.dice = null;
        deadlineMs = now + turnMs;
      } else {
        _passTurn(now);
      }
    }
    return {
      'type': 'move',
      'seat': seat,
      'token': token,
      'from': out.from,
      'to': out.to,
      'captured': out.captured,
      'home': out.reachedHome,
      'extra': extra,
    };
  }

  void _commit(int now, Map<String, dynamic> ev) {
    seq++;
    lastActionMs = now;
    event = ev;
  }

  // ------------------------------------------------------------ public actions
  void humanRoll(int now, int givenSeq) {
    _guard(now, givenSeq, 'human');
    if (state.turn != human) throw RejectedAction('Not your turn');
    if (state.dice != null) throw RejectedAction('Dice already rolled');
    _commit(now, _doRoll(now));
  }

  void humanMove(int now, int givenSeq, int token) {
    _guard(now, givenSeq, 'human');
    if (state.turn != human) throw RejectedAction('Not your turn');
    _commit(now, _doMove(token, now));
  }

  /// One bot action: roll when no dice is pending, otherwise choose and apply a move.
  void botStep(int now, int givenSeq, Random rng) {
    _guard(now, givenSeq, 'bot');
    final seat = state.turn;
    final info = seats[seat];
    if (!info.isBot) throw RejectedAction('Not a bot turn');
    if (state.dice == null) {
      _commit(now, _doRoll(now));
      return;
    }
    final token = BotBrain.choose(state, seat, state.dice!, info.difficulty ?? 'medium', info.persona ?? 'strategist', rng);
    _commit(now, _doMove(token, now));
  }

  /// Server-side turn timer: honoured only once the deadline has really passed.
  void timeoutTurn(int now, int givenSeq, Random rng) {
    if (over) throw RejectedAction('Match is already over');
    if (givenSeq != seq) throw RejectedAction('Stale or replayed request');
    if (now < deadlineMs) throw RejectedAction('Turn timer has not expired');
    if (seats[state.turn].isBot) throw RejectedAction('Not a human turn');
    _addLog(now, 'timeout', '${_name(state.turn)} ran out of time - auto play');
    Map<String, dynamic> ev;
    if (state.dice == null) {
      ev = _doRoll(now);
      if (state.turn == human && state.dice != null) {
        final tok = BotBrain.choose(state, human, state.dice!, 'medium', 'strategist', rng);
        ev = _doMove(tok, now);
      }
    } else {
      final tok = BotBrain.choose(state, human, state.dice!, 'medium', 'strategist', rng);
      ev = _doMove(tok, now);
    }
    _commit(now, ev);
  }

  void abandon(int now) {
    if (over) throw RejectedAction('Match is already over');
    over = true;
    status = 'abandoned';
    humanRank = 4;
    finalOrder = [1, 2, 3, 0];
    seq++;
    event = {'type': 'abandon'};
    _addLog(now, 'abandon', 'Player left the match. Entry forfeited (rank 4).');
  }

  /// JSON shape identical to functions/lib/match.js publicView().
  Map<String, dynamic> publicJson(int serverNow) {
    final legal = state.dice != null ? state.legalTokens(state.turn, state.dice!) : <int>[];
    return {
      'id': id,
      'mode': mode,
      'entry': entry,
      'seats': seats.map((s) => s.toJson()).toList(),
      'state': state.toJson(),
      'seq': seq,
      'status': status,
      'over': over,
      'finalOrder': finalOrder,
      'humanRank': humanRank,
      'payout': payout,
      'deadlineMs': deadlineMs,
      'turnMs': turnMs,
      'serverNowMs': serverNow,
      'legal': legal,
      'event': event,
      'commitment': commitment,
      'revealedSeed': over ? _seed : null,
      'multipliers': multipliers,
      'flagged': flagged,
    };
  }
}
