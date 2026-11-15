import 'dart:math';

import 'package:flutter/material.dart';

import '../services/models.dart';

/// Player progression. XP and daily rewards are granted by the backend only
/// (this file just holds the shared formulas, mirrored in functions/lib/rewards.js).
/// Neither XP nor levels are tied to money: they unlock titles and badges only.
class Progress {
  /// XP for a finished match (practice included). Abandoned matches earn nothing.
  static int xpForMatch({required int rank, required bool completed}) {
    if (!completed || rank < 1 || rank > 4) return 0;
    const bonus = [60, 25, 10, 0];
    return 20 + bonus[rank - 1];
  }

  static int levelOf(int xp) => sqrt(max(0, xp) / 50).floor() + 1;
  static int xpAtLevel(int level) => (level - 1) * (level - 1) * 50;

  /// 0..1 progress through the current level.
  static double fraction(int xp) {
    final l = levelOf(xp);
    final lo = xpAtLevel(l), hi = xpAtLevel(l + 1);
    return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  static String title(int level) {
    if (level >= 15) return 'Ludo Legend';
    if (level >= 10) return 'Grand Master';
    if (level >= 7) return 'Champion';
    if (level >= 5) return 'Pro Player';
    if (level >= 3) return 'Rising Star';
    return 'Rookie';
  }

  /// Demo-coin reward for each day of the 7-day streak cycle.
  static const List<int> dailyAmounts = [50, 75, 100, 150, 200, 300, 500];
}

class Achievement {
  final String title;
  final String hint;
  final IconData icon;
  final bool Function(UserProfile p) done;
  const Achievement(this.title, this.hint, this.icon, this.done);
}

final List<Achievement> kAchievements = [
  Achievement('First Win', 'Win a paid match', Icons.emoji_events, (p) => p.wins >= 1),
  Achievement('Hat-trick', 'Win 3 matches', Icons.local_fire_department, (p) => p.wins >= 3),
  Achievement('Dominator', 'Win 10 matches', Icons.military_tech, (p) => p.wins >= 10),
  Achievement('Regular', 'Play 10 paid matches', Icons.casino, (p) => p.played >= 10),
  Achievement('Rising Star', 'Reach level 3', Icons.star, (p) => Progress.levelOf(p.xp) >= 3),
  Achievement('Pro Player', 'Reach level 5', Icons.workspace_premium, (p) => Progress.levelOf(p.xp) >= 5),
  Achievement('Sharp', 'Win rate 50%+ (5+ matches)', Icons.track_changes, (p) => p.played >= 5 && p.winRate >= 50),
  Achievement('In the Green', 'Positive simulated earnings', Icons.trending_up, (p) => p.played >= 1 && p.earnings > 0),
];
