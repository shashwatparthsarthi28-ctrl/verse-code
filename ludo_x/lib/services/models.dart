import '../engine/ludo_engine.dart';

num _n(dynamic v, [num d = 0]) => v is num ? v : d;
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();

class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

class UserProfile {
  final String uid;
  final String username;
  final String email;
  final int avatar;
  final int played;
  final int wins;
  final int losses;
  final double earnings;
  final double balance;
  final int xp;
  final bool isAdmin;
  final bool isGuest;

  const UserProfile({
    required this.uid,
    required this.username,
    this.email = '',
    this.avatar = 0,
    this.played = 0,
    this.wins = 0,
    this.losses = 0,
    this.earnings = 0,
    this.balance = 0,
    this.xp = 0,
    this.isAdmin = false,
    this.isGuest = false,
  });

  double get winRate => played == 0 ? 0 : wins / played * 100;
}

class WalletTxn {
  final String id;
  final String type; // deposit, withdrawal, entry, reward, bonus
  final double amount; // signed
  final double balanceAfter;
  final String note;
  final int ts;
  final String? status;
  final String? matchId;

  const WalletTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.note,
    required this.ts,
    this.status,
    this.matchId,
  });

  factory WalletTxn.fromJson(String id, Map<dynamic, dynamic> j) => WalletTxn(
        id: id,
        type: _s(j['type']),
        amount: _n(j['amount']).toDouble(),
        balanceAfter: _n(j['balanceAfter']).toDouble(),
        note: _s(j['note']),
        ts: _n(j['ts']).toInt(),
        status: j['status'] == null ? null : _s(j['status']),
        matchId: j['matchId'] == null ? null : _s(j['matchId']),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'note': note,
        'ts': ts,
        'status': status,
        'matchId': matchId,
      };

  /// Withdrawals are simulated: a pending request "settles" after 10 seconds.
  String? get displayStatus {
    if (type != 'withdrawal') return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return age > 10000 ? 'Completed (simulated)' : 'Pending (simulated)';
  }
}

class MatchRecord {
  final String id;
  final String mode;
  final double entry;
  final double payout;
  final int rank;
  final int ts;
  final bool completed;
  final String difficulty;

  const MatchRecord({
    required this.id,
    required this.mode,
    required this.entry,
    required this.payout,
    required this.rank,
    required this.ts,
    required this.completed,
    required this.difficulty,
  });

  double get net => payout - entry;

  factory MatchRecord.fromJson(String id, Map<dynamic, dynamic> j) => MatchRecord(
        id: id,
        mode: _s(j['mode']),
        entry: _n(j['entry']).toDouble(),
        payout: _n(j['payout']).toDouble(),
        rank: _n(j['rank'], 4).toInt(),
        ts: _n(j['ts']).toInt(),
        completed: j['completed'] != false,
        difficulty: _s(j['difficulty']),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'entry': entry,
        'payout': payout,
        'rank': rank,
        'ts': ts,
        'completed': completed,
        'difficulty': difficulty,
      };
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final int ts;
  final bool read;
  const AppNotification({required this.id, required this.title, required this.body, required this.ts, this.read = false});

  factory AppNotification.fromJson(String id, Map<dynamic, dynamic> j) => AppNotification(
        id: id,
        title: _s(j['title']),
        body: _s(j['body']),
        ts: _n(j['ts']).toInt(),
        read: j['read'] == true,
      );

  Map<String, dynamic> toJson() => {'title': title, 'body': body, 'ts': ts, 'read': read};
}

class LeaderEntry {
  final String uid;
  final String username;
  final int avatar;
  final int wins;
  final double earnings;
  final bool sample;
  const LeaderEntry({
    required this.uid,
    required this.username,
    this.avatar = 0,
    this.wins = 0,
    this.earnings = 0,
    this.sample = false,
  });
}

class LogEntry {
  final int n;
  final int ts;
  final String type;
  final String text;
  final String hash;
  const LogEntry({required this.n, required this.ts, required this.type, required this.text, required this.hash});

  factory LogEntry.fromJson(Map<dynamic, dynamic> j) => LogEntry(
        n: _n(j['n']).toInt(),
        ts: _n(j['ts']).toInt(),
        type: _s(j['type']),
        text: _s(j['text']),
        hash: _s(j['hash']),
      );

  Map<String, dynamic> toJson() => {'n': n, 'ts': ts, 'type': type, 'text': text, 'hash': hash};
}

class GameConfig {
  final double competitiveEntry;
  final List<double> proTiers;
  final List<double> multipliers;
  final int turnSeconds;
  final int botThinkMs;
  final String competitiveBotDifficulty;
  final List<String> botNames;
  final double maxDemoDeposit;
  final double maxBalance;
  final double starterBalance;

  const GameConfig({
    this.competitiveEntry = 100,
    this.proTiers = const [50, 100, 200],
    this.multipliers = const [1.6, 1.2, 0.7, 0.0],
    this.turnSeconds = 20,
    this.botThinkMs = 900,
    this.competitiveBotDifficulty = 'medium',
    this.botNames = const ['Rex', 'Nova', 'Zed'],
    this.maxDemoDeposit = 10000,
    this.maxBalance = 100000,
    this.starterBalance = 1000,
  });

  GameConfig copyWith({
    double? competitiveEntry,
    List<double>? proTiers,
    List<double>? multipliers,
    int? turnSeconds,
    String? competitiveBotDifficulty,
    List<String>? botNames,
  }) =>
      GameConfig(
        competitiveEntry: competitiveEntry ?? this.competitiveEntry,
        proTiers: proTiers ?? this.proTiers,
        multipliers: multipliers ?? this.multipliers,
        turnSeconds: turnSeconds ?? this.turnSeconds,
        botThinkMs: botThinkMs,
        competitiveBotDifficulty: competitiveBotDifficulty ?? this.competitiveBotDifficulty,
        botNames: botNames ?? this.botNames,
        maxDemoDeposit: maxDemoDeposit,
        maxBalance: maxBalance,
        starterBalance: starterBalance,
      );

  factory GameConfig.fromJson(Map<dynamic, dynamic> j) {
    const d = GameConfig();
    List<double> dl(dynamic v, List<double> fb) => v is List ? v.map((e) => _n(e).toDouble()).toList() : fb;
    return GameConfig(
      competitiveEntry: _n(j['competitiveEntry'], d.competitiveEntry).toDouble(),
      proTiers: dl(j['proTiers'], d.proTiers),
      multipliers: dl(j['multipliers'], d.multipliers),
      turnSeconds: _n(j['turnSeconds'], d.turnSeconds).toInt(),
      botThinkMs: _n(j['botThinkMs'], d.botThinkMs).toInt(),
      competitiveBotDifficulty: _s(j['competitiveBotDifficulty'], d.competitiveBotDifficulty),
      botNames: j['botNames'] is List ? (j['botNames'] as List).map((e) => e.toString()).toList() : d.botNames,
      maxDemoDeposit: _n(j['maxDemoDeposit'], d.maxDemoDeposit).toDouble(),
      maxBalance: _n(j['maxBalance'], d.maxBalance).toDouble(),
      starterBalance: _n(j['starterBalance'], d.starterBalance).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'competitiveEntry': competitiveEntry,
        'proTiers': proTiers,
        'multipliers': multipliers,
        'turnSeconds': turnSeconds,
        'botThinkMs': botThinkMs,
        'competitiveBotDifficulty': competitiveBotDifficulty,
        'botNames': botNames,
        'maxDemoDeposit': maxDemoDeposit,
        'maxBalance': maxBalance,
        'starterBalance': starterBalance,
      };
}

class AdminStats {
  final int users;
  final int matches;
  final int completed;
  final double entries;
  final double payouts;
  final GameConfig config;
  const AdminStats({
    required this.users,
    required this.matches,
    required this.completed,
    required this.entries,
    required this.payouts,
    required this.config,
  });

  double get completionRate => matches == 0 ? 0 : completed / matches * 100;
  double get margin => entries - payouts;
  double get marginPct => entries == 0 ? 0 : margin / entries * 100;
}

// ---------------------------------------------------------------- match snapshot

class SeatInfo {
  final int seat;
  final bool isBot;
  final String name;
  final String? difficulty;
  final String? persona;
  const SeatInfo({required this.seat, required this.isBot, required this.name, this.difficulty, this.persona});

  String get displayName => isBot ? '$name (AI)' : name;

  factory SeatInfo.fromJson(Map<dynamic, dynamic> j) => SeatInfo(
        seat: _n(j['seat']).toInt(),
        isBot: j['isBot'] == true,
        name: _s(j['name']),
        difficulty: j['difficulty'] == null ? null : _s(j['difficulty']),
        persona: j['persona'] == null ? null : _s(j['persona']),
      );

  Map<String, dynamic> toJson() => {
        'seat': seat,
        'isBot': isBot,
        'name': name,
        'difficulty': difficulty,
        'persona': persona,
      };
}

class MatchEvent {
  final String type; // roll | move | abandon
  final int seat;
  final int value; // roll
  final List<int> legal;
  final String? skipped; // no_moves | three_sixes
  final int token;
  final int from;
  final int to;
  final List<List<int>> captured;
  final bool home;
  final bool extra;

  const MatchEvent({
    required this.type,
    this.seat = 0,
    this.value = 0,
    this.legal = const [],
    this.skipped,
    this.token = 0,
    this.from = 0,
    this.to = 0,
    this.captured = const [],
    this.home = false,
    this.extra = false,
  });

  factory MatchEvent.fromJson(Map<dynamic, dynamic> j) => MatchEvent(
        type: _s(j['type']),
        seat: _n(j['seat']).toInt(),
        value: _n(j['value']).toInt(),
        legal: j['legal'] is List ? (j['legal'] as List).map((e) => _n(e).toInt()).toList() : const [],
        skipped: j['skipped'] == null ? null : _s(j['skipped']),
        token: _n(j['token']).toInt(),
        from: _n(j['from']).toInt(),
        to: _n(j['to']).toInt(),
        captured: j['captured'] is List
            ? (j['captured'] as List).map((p) => (p as List).map((e) => _n(e).toInt()).toList()).toList()
            : const [],
        home: j['home'] == true,
        extra: j['extra'] == true,
      );
}

/// Everything the client may know about a match. Dice seeds stay on the server
/// until the match is over (revealedSeed), so the client can never predict rolls.
class MatchSnapshot {
  final String id;
  final String mode;
  final double entry;
  final List<SeatInfo> seats;
  final LudoState state;
  final int seq;
  final String status;
  final bool over;
  final List<int> finalOrder;
  final int humanRank;
  final double payout;
  final int deadlineMs;
  final int turnMs;
  final int serverNowMs;
  final List<int> legal;
  final MatchEvent? event;
  final String commitment;
  final String? revealedSeed;
  final List<double> multipliers;
  final bool resumed;

  const MatchSnapshot({
    required this.id,
    required this.mode,
    required this.entry,
    required this.seats,
    required this.state,
    required this.seq,
    required this.status,
    required this.over,
    required this.finalOrder,
    required this.humanRank,
    required this.payout,
    required this.deadlineMs,
    required this.turnMs,
    required this.serverNowMs,
    required this.legal,
    required this.event,
    required this.commitment,
    required this.revealedSeed,
    required this.multipliers,
    this.resumed = false,
  });

  int get turn => state.turn;
  int? get dice => state.dice;
  List<List<int>> get tokens => state.tokens;
  bool get humanTurn => !over && !seats[state.turn].isBot;

  factory MatchSnapshot.fromJson(Map<dynamic, dynamic> j) => MatchSnapshot(
        id: _s(j['id']),
        mode: _s(j['mode']),
        entry: _n(j['entry']).toDouble(),
        seats: (j['seats'] as List).map((e) => SeatInfo.fromJson(e as Map)).toList(),
        state: LudoState.fromJson(j['state'] as Map),
        seq: _n(j['seq']).toInt(),
        status: _s(j['status'], 'active'),
        over: j['over'] == true,
        finalOrder: j['finalOrder'] is List ? (j['finalOrder'] as List).map((e) => _n(e).toInt()).toList() : const [],
        humanRank: _n(j['humanRank']).toInt(),
        payout: _n(j['payout']).toDouble(),
        deadlineMs: _n(j['deadlineMs']).toInt(),
        turnMs: _n(j['turnMs'], 20000).toInt(),
        serverNowMs: _n(j['serverNowMs']).toInt(),
        legal: j['legal'] is List ? (j['legal'] as List).map((e) => _n(e).toInt()).toList() : const [],
        event: j['event'] is Map ? MatchEvent.fromJson(j['event'] as Map) : null,
        commitment: _s(j['commitment']),
        revealedSeed: j['revealedSeed'] == null ? null : _s(j['revealedSeed']),
        multipliers: j['multipliers'] is List
            ? (j['multipliers'] as List).map((e) => _n(e).toDouble()).toList()
            : const [1.6, 1.2, 0.7, 0.0],
        resumed: j['resumed'] == true,
      );
}

/// Daily reward state. [streak] = consecutive days claimed (before today's claim
/// if not yet claimed), [nextDay] = 1..7 slot that the next claim pays,
/// [doneCount] = slots to show as completed in the current 7-day cycle.
class DailyStatus {
  final int streak;
  final bool claimedToday;
  final int nextDay;
  final int doneCount;
  const DailyStatus({required this.streak, required this.claimedToday, required this.nextDay, required this.doneCount});

  factory DailyStatus.fromJson(Map<dynamic, dynamic> j) => DailyStatus(
        streak: _n(j['streak']).toInt(),
        claimedToday: j['claimedToday'] == true,
        nextDay: _n(j['nextDay'], 1).toInt(),
        doneCount: _n(j['doneCount']).toInt(),
      );
}
