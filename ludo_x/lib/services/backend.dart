import 'models.dart';

/// All game, wallet and match state goes through this interface.
///
/// * [FirebaseBackend]: Firebase Auth + Firestore (read-only for the client) +
///   Cloud Functions (every mutation: dice, moves, wallet, payouts).
/// * [LocalBackend]: the same server-side logic running in-process, used when
///   Firebase has not been configured so the prototype always runs.
///
/// Either way the UI cannot touch balances, dice or match state directly.
abstract class GameBackend {
  bool get isLocal;
  String get label;

  Future<void> init();

  bool get signedIn;
  Future<void> register(String email, String password, String username);
  Future<void> signIn(String email, String password);
  Future<void> signInGuest(String username);
  Future<void> signOut();
  Future<void> resetLocalData();

  Future<UserProfile> getProfile();
  Future<void> updateProfile(String username, int avatar);

  Future<List<WalletTxn>> getTransactions();
  Future<void> demoDeposit(double amount);
  Future<void> requestWithdrawal(double amount);

  Future<List<MatchRecord>> getHistory();
  Future<List<LeaderEntry>> getLeaderboard();
  Future<List<AppNotification>> getNotifications();
  Future<void> markNotificationsRead();
  Future<GameConfig> getConfig();
  Future<DailyStatus> getDaily();
  Future<int> claimDaily();

  Future<MatchSnapshot> createMatch({required String mode, double entry = 0, List<String>? difficulties});
  Future<MatchSnapshot> getMatch(String id);
  Future<MatchSnapshot> rollDice(String id, int seq);
  Future<MatchSnapshot> moveToken(String id, int token, int seq);
  Future<MatchSnapshot> botStep(String id, int seq);
  Future<MatchSnapshot> timeoutTurn(String id, int seq);
  Future<MatchSnapshot> abandonMatch(String id);
  Future<MatchLogBundle> getMatchLog(String id);

  Future<AdminStats> getAdminStats();
  Future<void> setConfig(GameConfig config);
}

class MatchLogBundle {
  final String commitment;
  final String? revealedSeed;
  final List<LogEntry> entries;
  const MatchLogBundle({required this.commitment, required this.revealedSeed, required this.entries});
}
