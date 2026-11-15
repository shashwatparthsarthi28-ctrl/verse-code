import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/payout.dart';
import '../core/progress.dart';
import '../engine/fair_dice.dart';
import '../server/server_match.dart';
import 'backend.dart';
import 'models.dart';

/// In-process "server". Wallet, dice and match state live here, never in widgets.
/// Everything is SIMULATED MONEY: nothing in this class can move real funds.
class LocalBackend implements GameBackend {
  static const String _key = 'ludox_local_v1';

  late SharedPreferences _p;
  Map<String, dynamic> _d = {};
  final Map<String, ServerMatch> _matches = {};
  final Random _rng = Random.secure();

  @override
  bool get isLocal => true;
  @override
  String get label => 'Local simulation';

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString(_key);
    if (raw != null) {
      try {
        _d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _d = {};
      }
    }
    await _settleOrphan();
  }

  Future<void> _save() async => _p.setString(_key, jsonEncode(_d));

  // ------------------------------------------------------------ small helpers
  Map<String, dynamic>? get _account => _d['account'] == null ? null : Map<String, dynamic>.from(_d['account'] as Map);
  double get _balance => ((_d['balance'] ?? 0) as num).toDouble();
  List<dynamic> _list(String k) => (_d[k] ??= <dynamic>[]) as List<dynamic>;
  Map<String, dynamic> _map(String k) => Map<String, dynamic>.from((_d[k] ??= <String, dynamic>{}) as Map);
  String _id() => '${_now.toRadixString(36)}${_rng.nextInt(1 << 30).toRadixString(36)}';
  String _hash(String salt, String pw) => FairDice.sha256Hex('$salt:$pw');

  GameConfig get _config => GameConfig.fromJson(_d['config'] is Map ? _d['config'] as Map : {});

  WalletTxn _ledger(String type, double amount, String note, {String? status, String? matchId}) {
    final bal = r2(_balance + amount);
    if (bal < 0) throw BackendException('Insufficient demo balance');
    _d['balance'] = bal;
    final t = WalletTxn(
      id: _id(),
      type: type,
      amount: r2(amount),
      balanceAfter: bal,
      note: note,
      ts: _now,
      status: status,
      matchId: matchId,
    );
    _list('txns').insert(0, {'id': t.id, ...t.toJson()});
    return t;
  }

  void _notify(String title, String body) {
    _list('notifs').insert(0, {'id': _id(), ...AppNotification(id: '', title: title, body: body, ts: _now).toJson()});
    if (_list('notifs').length > 60) _list('notifs').removeLast();
  }

  void _bumpStats({int matches = 0, int completed = 0, double entries = 0, double payouts = 0}) {
    final s = _map('stats');
    s['matches'] = ((s['matches'] ?? 0) as num).toInt() + matches;
    s['completed'] = ((s['completed'] ?? 0) as num).toInt() + completed;
    s['entries'] = r2(((s['entries'] ?? 0) as num).toDouble() + entries);
    s['payouts'] = r2(((s['payouts'] ?? 0) as num).toDouble() + payouts);
    _d['stats'] = s;
  }

  // ------------------------------------------------------------ auth
  @override
  bool get signedIn => _d['signedIn'] == true && _account != null;

  Future<void> _createAccount({required String email, required String pw, required String username, required bool guest}) async {
    final salt = _id();
    _d = {
      'account': {
        'uid': 'local-${_id()}',
        'email': email,
        'salt': salt,
        'pw': guest ? '' : _hash(salt, pw),
        'username': username,
        'avatar': 0,
        'guest': guest,
        'createdAt': _now,
        'played': 0,
        'wins': 0,
        'losses': 0,
        'earnings': 0.0,
      },
      'signedIn': true,
      'balance': 0.0,
      'txns': <dynamic>[],
      'history': <dynamic>[],
      'notifs': <dynamic>[],
      'logs': <String, dynamic>{},
      'logOrder': <dynamic>[],
      'stats': {'matches': 0, 'completed': 0, 'entries': 0.0, 'payouts': 0.0},
      'config': _d['config'] ?? _config.toJson(),
    };
    _ledger('bonus', _config.starterBalance, 'Welcome demo balance (simulated)');
    _notify('Welcome to LUDO X', 'Your simulated wallet is funded. No real money is ever used.');
    await _save();
  }

  void _checkName(String username) {
    final u = username.trim();
    if (u.length < 3 || u.length > 16) throw BackendException('Username must be 3-16 characters');
  }

  @override
  Future<void> register(String email, String password, String username) async {
    _checkName(username);
    if (!email.contains('@') || !email.contains('.')) throw BackendException('Enter a valid email');
    if (password.length < 6) throw BackendException('Password must be at least 6 characters');
    if (_account != null) {
      throw BackendException('A local account already exists on this device. Sign in, or reset local data.');
    }
    await _createAccount(email: email.trim().toLowerCase(), pw: password, username: username.trim(), guest: false);
  }

  @override
  Future<void> signIn(String email, String password) async {
    final a = _account;
    if (a == null) throw BackendException('No local account yet. Register first.');
    if (a['guest'] == true) throw BackendException('This device has a guest account. Use "Continue as guest".');
    if (a['email'] != email.trim().toLowerCase() || a['pw'] != _hash(a['salt'] as String, password)) {
      throw BackendException('Wrong email or password');
    }
    _d['signedIn'] = true;
    await _save();
  }

  @override
  Future<void> signInGuest(String username) async {
    if (_account == null) {
      _checkName(username);
      await _createAccount(email: '', pw: '', username: username.trim(), guest: true);
    } else {
      if (_account!['guest'] != true) throw BackendException('Sign in with your email and password.');
      _d['signedIn'] = true;
      await _save();
    }
  }

  @override
  Future<void> signOut() async {
    _d['signedIn'] = false;
    await _save();
  }

  @override
  Future<void> resetLocalData() async {
    _matches.clear();
    final cfg = _d['config'];
    _d = {if (cfg != null) 'config': cfg};
    await _save();
  }

  // ------------------------------------------------------------ profile & wallet
  @override
  Future<UserProfile> getProfile() async {
    final a = _account;
    if (a == null) throw BackendException('Not signed in');
    return UserProfile(
      uid: a['uid'] as String,
      username: a['username'] as String,
      email: (a['email'] ?? '') as String,
      avatar: ((a['avatar'] ?? 0) as num).toInt(),
      played: ((a['played'] ?? 0) as num).toInt(),
      wins: ((a['wins'] ?? 0) as num).toInt(),
      losses: ((a['losses'] ?? 0) as num).toInt(),
      earnings: ((a['earnings'] ?? 0) as num).toDouble(),
      balance: _balance,
      xp: ((a['xp'] ?? 0) as num).toInt(),
      isAdmin: true, // local demo: the single user can open the admin dashboard
      isGuest: a['guest'] == true,
    );
  }

  @override
  Future<void> updateProfile(String username, int avatar) async {
    _checkName(username);
    final a = _account!;
    a['username'] = username.trim();
    a['avatar'] = avatar.clamp(0, 11);
    _d['account'] = a;
    await _save();
  }

  @override
  Future<List<WalletTxn>> getTransactions() async =>
      _list('txns').map((e) => WalletTxn.fromJson((e as Map)['id'] as String, e)).toList();

  @override
  Future<void> demoDeposit(double amount) async {
    final cfg = _config;
    amount = r2(amount);
    if (amount <= 0 || amount > cfg.maxDemoDeposit) {
      throw BackendException('Demo deposit must be between 1 and ${cfg.maxDemoDeposit.toStringAsFixed(0)}');
    }
    if (_balance + amount > cfg.maxBalance) throw BackendException('Demo balance limit reached');
    _ledger('deposit', amount, 'Demo deposit (simulated - no real money)');
    await _save();
  }

  @override
  Future<void> requestWithdrawal(double amount) async {
    amount = r2(amount);
    if (amount <= 0) throw BackendException('Enter an amount');
    if (amount > _balance) throw BackendException('Insufficient demo balance');
    _ledger('withdrawal', -amount, 'Simulated withdrawal request (no real payout)', status: 'pending');
    _notify('Withdrawal request received', 'Simulated withdrawal of ${amount.toStringAsFixed(2)} is pending. Nothing is paid out.');
    await _save();
  }

  @override
  Future<List<MatchRecord>> getHistory() async =>
      _list('history').map((e) => MatchRecord.fromJson((e as Map)['id'] as String, e)).toList();

  @override
  Future<List<LeaderEntry>> getLeaderboard() async {
    final a = _account;
    final list = <LeaderEntry>[
      // Clearly labelled sample rows so a fresh install shows a populated board.
      const LeaderEntry(uid: 's1', username: 'Aarav', avatar: 3, wins: 14, earnings: 840, sample: true),
      const LeaderEntry(uid: 's2', username: 'Diya', avatar: 5, wins: 11, earnings: 610, sample: true),
      const LeaderEntry(uid: 's3', username: 'Kabir', avatar: 7, wins: 9, earnings: 420, sample: true),
      const LeaderEntry(uid: 's4', username: 'Meera', avatar: 1, wins: 7, earnings: 275, sample: true),
      const LeaderEntry(uid: 's5', username: 'Rohan', avatar: 9, wins: 5, earnings: 130, sample: true),
    ];
    if (a != null) {
      list.add(LeaderEntry(
        uid: a['uid'] as String,
        username: a['username'] as String,
        avatar: ((a['avatar'] ?? 0) as num).toInt(),
        wins: ((a['wins'] ?? 0) as num).toInt(),
        earnings: ((a['earnings'] ?? 0) as num).toDouble(),
      ));
    }
    list.sort((x, y) {
      final c = y.wins.compareTo(x.wins);
      return c != 0 ? c : y.earnings.compareTo(x.earnings);
    });
    return list;
  }

  @override
  Future<List<AppNotification>> getNotifications() async =>
      _list('notifs').map((e) => AppNotification.fromJson((e as Map)['id'] as String, e)).toList();

  @override
  Future<void> markNotificationsRead() async {
    for (final e in _list('notifs')) {
      (e as Map)['read'] = true;
    }
    await _save();
  }

  @override
  Future<GameConfig> getConfig() async => _config;

  // ------------------------------------------------------------ daily reward
  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  DailyStatus _dailyStatus() {
    final dd = _map('daily');
    final last = dd['last'] as String?;
    final streak = ((dd['streak'] ?? 0) as num).toInt();
    final now = DateTime.now();
    if (last == _dayKey(now)) {
      return DailyStatus(streak: streak, claimedToday: true, nextDay: (streak % 7) + 1, doneCount: ((streak - 1) % 7) + 1);
    }
    final eff = last == _dayKey(now.subtract(const Duration(days: 1))) ? streak : 0;
    return DailyStatus(streak: eff, claimedToday: false, nextDay: (eff % 7) + 1, doneCount: eff % 7);
  }

  @override
  Future<DailyStatus> getDaily() async => _dailyStatus();

  @override
  Future<int> claimDaily() async {
    final st = _dailyStatus();
    if (st.claimedToday) throw BackendException('Already claimed today. Come back tomorrow!');
    final amount = Progress.dailyAmounts[st.nextDay - 1];
    if (_balance + amount > _config.maxBalance) throw BackendException('Demo balance limit reached');
    _ledger('bonus', amount.toDouble(), 'Daily reward - day ${st.nextDay} (simulated)');
    _d['daily'] = {'last': _dayKey(DateTime.now()), 'streak': st.streak + 1};
    _notify('Daily reward claimed', '+\u20b9$amount demo coins. Streak: ${st.streak + 1} day(s).');
    await _save();
    return amount;
  }

  // ------------------------------------------------------------ matches
  @override
  Future<MatchSnapshot> createMatch({required String mode, double entry = 0, List<String>? difficulties}) async {
    if (!['practice', 'competitive', 'pro'].contains(mode)) throw BackendException('Unknown mode');
    // resume an active match instead of charging twice
    for (final m in _matches.values) {
      if (!m.over) return _snap(m, resumed: true);
    }
    final cfg = _config;
    var fee = 0.0;
    var diffs = (difficulties != null && difficulties.length == 3) ? difficulties : ['medium', 'medium', 'medium'];
    if (mode == 'competitive') {
      fee = cfg.competitiveEntry;
      diffs = List.filled(3, cfg.competitiveBotDifficulty);
    } else if (mode == 'pro') {
      fee = entry;
      if (!cfg.proTiers.contains(fee)) throw BackendException('Invalid entry tier');
    }
    if (!diffs.every((d) => ['easy', 'medium', 'hard'].contains(d))) throw BackendException('Invalid bot difficulty');
    final id = _id();
    if (fee > 0) {
      _ledger('entry', -fee, '${mode == 'pro' ? 'Pro Bot Challenge' : 'Competitive Demo'} entry (simulated)', matchId: id);
    }
    final a = _account!;
    final m = ServerMatch.create(
      id: id,
      username: a['username'] as String,
      mode: mode,
      entry: fee,
      botNames: cfg.botNames,
      difficulties: diffs,
      multipliers: cfg.multipliers,
      turnSeconds: cfg.turnSeconds,
      now: _now,
      rng: _rng,
    );
    _matches[id] = m;
    _d['activeMatch'] = {'id': id, 'mode': mode, 'entry': fee, 'multipliers': cfg.multipliers};
    _bumpStats(matches: 1, entries: fee > 0 ? fee * 4 : 0); // pool includes the 3 AI demo entries
    await _save();
    return _snap(m);
  }

  MatchSnapshot _snap(ServerMatch m, {bool resumed = false}) {
    final j = m.publicJson(_now);
    j['resumed'] = resumed;
    return MatchSnapshot.fromJson(j);
  }

  Future<MatchSnapshot> _act(String id, void Function(ServerMatch m, int now) fn) async {
    final m = _matches[id];
    if (m == null) throw BackendException('Match not found');
    final now = _now;
    final wasOver = m.over;
    try {
      fn(m, now);
    } on RejectedAction catch (e) {
      m.recordViolation(now, e.message);
      throw BackendException(e.message);
    }
    if (!wasOver && m.over) await _settle(m);
    return _snap(m);
  }

  @override
  Future<MatchSnapshot> getMatch(String id) async {
    final m = _matches[id];
    if (m == null) throw BackendException('Match not found');
    return _snap(m);
  }

  @override
  Future<MatchSnapshot> rollDice(String id, int seq) => _act(id, (m, now) => m.humanRoll(now, seq));

  @override
  Future<MatchSnapshot> moveToken(String id, int token, int seq) => _act(id, (m, now) => m.humanMove(now, seq, token));

  @override
  Future<MatchSnapshot> botStep(String id, int seq) => _act(id, (m, now) => m.botStep(now, seq, _rng));

  @override
  Future<MatchSnapshot> timeoutTurn(String id, int seq) => _act(id, (m, now) => m.timeoutTurn(now, seq, _rng));

  @override
  Future<MatchSnapshot> abandonMatch(String id) => _act(id, (m, now) => m.abandon(now));

  /// Settlement is the ONLY place rewards are credited, and only the server side calls it.
  Future<void> _settle(ServerMatch m) async {
    final paid = m.entry > 0;
    final table = PayoutConfig(entry: m.entry, multipliers: m.multipliers);
    final payout = (paid && m.status == 'completed') ? table.payoutForRank(m.humanRank) : 0.0;
    m.payout = payout;
    if (payout > 0) _ledger('reward', payout, 'Rank ${m.humanRank} reward (simulated)', matchId: m.id);
    final a = _account!;
    if (paid) {
      a['played'] = ((a['played'] ?? 0) as num).toInt() + 1;
      if (m.humanRank == 1) {
        a['wins'] = ((a['wins'] ?? 0) as num).toInt() + 1;
      } else {
        a['losses'] = ((a['losses'] ?? 0) as num).toInt() + 1;
      }
      a['earnings'] = r2(((a['earnings'] ?? 0) as num).toDouble() + payout - m.entry);
      _d['account'] = a;
    }
    a['xp'] = ((a['xp'] ?? 0) as num).toInt() + Progress.xpForMatch(rank: m.humanRank, completed: m.status == 'completed');
    _d['account'] = a;
    final rec = MatchRecord(
      id: m.id,
      mode: m.mode,
      entry: m.entry,
      payout: payout,
      rank: m.humanRank,
      ts: _now,
      completed: m.status == 'completed',
      difficulty: m.seats.where((s) => s.isBot).map((s) => s.difficulty).join('/'),
    );
    _list('history').insert(0, {'id': rec.id, ...rec.toJson()});
    if (_list('history').length > 200) _list('history').removeLast();
    _bumpStats(completed: m.status == 'completed' ? 1 : 0, payouts: payout);
    _notify(
      m.status == 'completed' ? 'Match finished: rank ${m.humanRank}' : 'Match abandoned',
      paid ? 'Simulated payout ${payout.toStringAsFixed(2)} (entry ${m.entry.toStringAsFixed(0)}).' : 'Practice match - no wallet changes.',
    );
    // keep the last 5 audit logs
    final logs = _map('logs');
    logs[m.id] = {
      'commitment': m.commitment,
      'seed': m.publicJson(_now)['revealedSeed'],
      'entries': m.log.map((e) => e.toJson()).toList(),
    };
    final order = _list('logOrder')..insert(0, m.id);
    while (order.length > 5) {
      logs.remove(order.removeLast());
    }
    _d['logs'] = logs;
    _d.remove('activeMatch');
    await _save();
  }

  /// If the app was killed mid-match, the entry was already charged: settle as abandoned.
  Future<void> _settleOrphan() async {
    final am = _d['activeMatch'];
    if (am is! Map || _account == null) {
      _d.remove('activeMatch');
      return;
    }
    final entry = ((am['entry'] ?? 0) as num).toDouble();
    final a = _account!;
    if (entry > 0) {
      a['played'] = ((a['played'] ?? 0) as num).toInt() + 1;
      a['losses'] = ((a['losses'] ?? 0) as num).toInt() + 1;
      a['earnings'] = r2(((a['earnings'] ?? 0) as num).toDouble() - entry);
      _d['account'] = a;
    }
    final rec = MatchRecord(
      id: am['id'] as String,
      mode: am['mode'] as String,
      entry: entry,
      payout: 0,
      rank: 4,
      ts: _now,
      completed: false,
      difficulty: '-',
    );
    _list('history').insert(0, {'id': rec.id, ...rec.toJson()});
    _bumpStats();
    _notify('Match abandoned', 'The app closed during a match. Entry forfeited (simulated).');
    _d.remove('activeMatch');
    await _save();
  }

  @override
  Future<MatchLogBundle> getMatchLog(String id) async {
    final m = _matches[id];
    if (m != null) {
      final j = m.publicJson(_now);
      return MatchLogBundle(commitment: m.commitment, revealedSeed: j['revealedSeed'] as String?, entries: List.of(m.log));
    }
    final stored = _map('logs')[id];
    if (stored is Map) {
      return MatchLogBundle(
        commitment: stored['commitment'] as String,
        revealedSeed: stored['seed'] as String?,
        entries: (stored['entries'] as List).map((e) => LogEntry.fromJson(e as Map)).toList(),
      );
    }
    throw BackendException('Log is no longer available (only the last 5 matches are kept locally).');
  }

  // ------------------------------------------------------------ admin
  @override
  Future<AdminStats> getAdminStats() async {
    final s = _map('stats');
    return AdminStats(
      users: _account == null ? 0 : 1,
      matches: ((s['matches'] ?? 0) as num).toInt(),
      completed: ((s['completed'] ?? 0) as num).toInt(),
      entries: ((s['entries'] ?? 0) as num).toDouble(),
      payouts: ((s['payouts'] ?? 0) as num).toDouble(),
      config: _config,
    );
  }

  @override
  Future<void> setConfig(GameConfig config) async {
    if (config.competitiveEntry <= 0) throw BackendException('Entry must be positive');
    if (config.multipliers.length != 4 || config.multipliers.any((m) => m < 0)) {
      throw BackendException('Four non-negative multipliers required');
    }
    if (config.proTiers.isEmpty || config.proTiers.any((t) => t <= 0)) throw BackendException('Add at least one positive tier');
    if (config.turnSeconds < 5 || config.turnSeconds > 120) throw BackendException('Turn timer must be 5-120 seconds');
    _d['config'] = config.toJson();
    await _save();
  }
}
