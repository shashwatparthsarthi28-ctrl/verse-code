import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Sound effects synthesised by scripts/make_sfx.py (assets/sfx/*.wav).
/// Never throws: audio problems must not break gameplay.
class Sfx {
  static bool enabled = true;
  static final Map<String, AudioPlayer> _players = {};

  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      final p = _players.putIfAbsent(name, () => AudioPlayer());
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'));
    } catch (_) {}
  }

  static void haptic({bool heavy = false}) {
    try {
      if (heavy) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }
}
