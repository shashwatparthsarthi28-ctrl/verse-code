import 'package:flutter/foundation.dart';

import '../services/backend.dart';
import '../services/models.dart';
import 'sound.dart';

/// App-wide state. Holds the signed-in profile (balance included) as returned
/// by the backend: the UI only ever displays it, it never edits it.
class AppController extends ChangeNotifier {
  late GameBackend backend;
  bool ready = false;
  UserProfile? profile;
  GameConfig config = const GameConfig();
  int unread = 0;

  bool get soundOn => Sfx.enabled;
  bool get signedIn => ready && profile != null;
  double get balance => profile?.balance ?? 0;

  Future<void> bootstrap(GameBackend b) async {
    backend = b;
    ready = true;
    if (b.signedIn) await refresh();
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      profile = await backend.getProfile();
      config = await backend.getConfig();
      final n = await backend.getNotifications();
      unread = n.where((x) => !x.read).length;
    } catch (e) {
      debugPrint('refresh failed: $e');
    }
    notifyListeners();
  }

  void toggleSound() {
    Sfx.enabled = !Sfx.enabled;
    notifyListeners();
  }

  Future<void> afterAuth() async {
    await refresh();
  }

  Future<void> signOut() async {
    await backend.signOut();
    profile = null;
    unread = 0;
    notifyListeners();
  }
}

final AppController app = AppController();
