import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'backend.dart';
import 'models.dart';

/// Production architecture:
///  * Firebase Authentication - email/password and anonymous (guest) sign-in
///  * Firestore - READ-ONLY for this client (see firestore.rules)
///  * Cloud Functions - every mutation: wallet, dice, moves, bot turns, payouts
///
/// The app never writes a balance or a dice value. It sends intents
/// (rollDice / moveToken / ...) and renders the state the server returns.
class FirebaseBackend implements GameBackend {
  late FirebaseAuth _auth;
  late FirebaseFirestore _fs;
  late FirebaseFunctions _fn;

  @override
  bool get isLocal => false;
  @override
  String get label => 'Firebase';

  @override
  Future<void> init() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    _auth = FirebaseAuth.instance;
    _fs = FirebaseFirestore.instance;
    _fn = FirebaseFunctions.instance;
  }

  String get _uid => _auth.currentUser!.uid;

  Future<Map<dynamic, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final r = await _fn.httpsCallable(name).call<dynamic>(data ?? <String, dynamic>{});
      return (r.data as Map?) ?? <dynamic, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(e.message ?? e.code);
    }
  }

  Future<T> _auth_<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw BackendException(e.message ?? e.code);
    }
  }

  // ------------------------------------------------------------ auth
  @override
  bool get signedIn => _auth.currentUser != null;

  @override
  Future<void> register(String email, String password, String username) => _auth_(() async {
        await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await _call('ensureProfile');
        await _call('updateProfile', {'username': username.trim(), 'avatar': 0});
      });

  @override
  Future<void> signIn(String email, String password) => _auth_(() async {
        await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        await _call('ensureProfile');
      });

  @override
  Future<void> signInGuest(String username) => _auth_(() async {
        await _auth.signInAnonymously();
        await _call('ensureProfile');
        if (username.trim().length >= 3) {
          await _call('updateProfile', {'username': username.trim(), 'avatar': 0});
        }
      });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> resetLocalData() async {}

  // ------------------------------------------------------------ profile & wallet
  @override
  Future<UserProfile> getProfile() async {
    var snap = await _fs.collection('users').doc(_uid).get();
    if (!snap.exists) {
      await _call('ensureProfile');
      snap = await _fs.collection('users').doc(_uid).get();
    }
    final d = snap.data() ?? <String, dynamic>{};
    final token = await _auth.currentUser!.getIdTokenResult();
    num n(dynamic v) => v is num ? v : 0;
    return UserProfile(
      uid: _uid,
      username: (d['username'] ?? 'Player').toString(),
      email: _auth.currentUser?.email ?? '',
      avatar: n(d['avatar']).toInt(),
      played: n(d['played']).toInt(),
      wins: n(d['wins']).toInt(),
      losses: n(d['losses']).toInt(),
      earnings: n(d['earnings']).toDouble(),
      balance: n(d['balance']).toDouble(),
      xp: n(d['xp']).toInt(),
      isAdmin: token.claims?['admin'] == true,
      isGuest: _auth.currentUser?.isAnonymous ?? false,
    );
  }

  @override
  Future<void> updateProfile(String username, int avatar) async {
    await _call('updateProfile', {'username': username.trim(), 'avatar': avatar});
  }

  @override
  Future<List<WalletTxn>> getTransactions() async {
    final q = await _fs.collection('users').doc(_uid).collection('transactions').orderBy('ts', descending: true).limit(100).get();
    return q.docs.map((d) => WalletTxn.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<void> demoDeposit(double amount) async {
    await _call('demoDeposit', {'amount': amount});
  }

  @override
  Future<void> requestWithdrawal(double amount) async {
    await _call('requestWithdrawal', {'amount': amount});
  }

  @override
  Future<List<MatchRecord>> getHistory() async {
    final q = await _fs.collection('users').doc(_uid).collection('matches').orderBy('ts', descending: true).limit(100).get();
    return q.docs.map((d) => MatchRecord.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<List<LeaderEntry>> getLeaderboard() async {
    final q = await _fs.collection('leaderboard').orderBy('wins', descending: true).limit(25).get();
    num n(dynamic v) => v is num ? v : 0;
    final list = q.docs
        .map((d) => LeaderEntry(
              uid: d.id,
              username: (d.data()['username'] ?? 'Player').toString(),
              avatar: n(d.data()['avatar']).toInt(),
              wins: n(d.data()['wins']).toInt(),
              earnings: n(d.data()['earnings']).toDouble(),
            ))
        .toList();
    return list;
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    final q = await _fs.collection('users').doc(_uid).collection('notifications').orderBy('ts', descending: true).limit(50).get();
    return q.docs.map((d) => AppNotification.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<void> markNotificationsRead() async {
    final q = await _fs.collection('users').doc(_uid).collection('notifications').where('read', isEqualTo: false).get();
    final batch = _fs.batch();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Future<GameConfig> getConfig() async {
    final snap = await _fs.collection('config').doc('game').get();
    return snap.exists ? GameConfig.fromJson(snap.data()!) : const GameConfig();
  }

  @override
  Future<DailyStatus> getDaily() async => DailyStatus.fromJson(await _call('dailyStatus'));

  @override
  Future<int> claimDaily() async {
    final r = await _call('claimDaily');
    return (r['amount'] as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------------ matches (all server authoritative)
  @override
  Future<MatchSnapshot> createMatch({required String mode, double entry = 0, List<String>? difficulties}) async {
    final r = await _call('createMatch', {
      'mode': mode,
      'entry': entry,
      if (difficulties != null) 'difficulties': difficulties,
    });
    return MatchSnapshot.fromJson(r);
  }

  @override
  Future<MatchSnapshot> getMatch(String id) async => MatchSnapshot.fromJson(await _call('getMatch', {'matchId': id}));

  @override
  Future<MatchSnapshot> rollDice(String id, int seq) async =>
      MatchSnapshot.fromJson(await _call('rollDice', {'matchId': id, 'seq': seq}));

  @override
  Future<MatchSnapshot> moveToken(String id, int token, int seq) async =>
      MatchSnapshot.fromJson(await _call('moveToken', {'matchId': id, 'seq': seq, 'token': token}));

  @override
  Future<MatchSnapshot> botStep(String id, int seq) async =>
      MatchSnapshot.fromJson(await _call('botStep', {'matchId': id, 'seq': seq}));

  @override
  Future<MatchSnapshot> timeoutTurn(String id, int seq) async =>
      MatchSnapshot.fromJson(await _call('timeoutTurn', {'matchId': id, 'seq': seq}));

  @override
  Future<MatchSnapshot> abandonMatch(String id) async =>
      MatchSnapshot.fromJson(await _call('abandonMatch', {'matchId': id, 'seq': 0}));

  @override
  Future<MatchLogBundle> getMatchLog(String id) async {
    final snap = await getMatch(id);
    final q = await _fs.collection('matches').doc(id).collection('log').orderBy('n').get();
    return MatchLogBundle(
      commitment: snap.commitment,
      revealedSeed: snap.revealedSeed,
      entries: q.docs.map((d) => LogEntry.fromJson(d.data())).toList(),
    );
  }

  // ------------------------------------------------------------ admin
  @override
  Future<AdminStats> getAdminStats() async {
    final r = await _call('adminStats');
    num n(dynamic v) => v is num ? v : 0;
    return AdminStats(
      users: n(r['users']).toInt(),
      matches: n(r['matches']).toInt(),
      completed: n(r['completed']).toInt(),
      entries: n(r['entries']).toDouble(),
      payouts: n(r['payouts']).toDouble(),
      config: GameConfig.fromJson((r['config'] as Map?) ?? <dynamic, dynamic>{}),
    );
  }

  @override
  Future<void> setConfig(GameConfig config) async {
    await _call('adminSetConfig', config.toJson());
  }
}
