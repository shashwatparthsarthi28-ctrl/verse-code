import 'dart:math';

import 'package:flutter/material.dart';

import '../core/progress.dart';
import '../core/theme.dart';
import '../services/models.dart';

/// Level badge + XP bar.
class LevelBar extends StatelessWidget {
  final int xp;
  const LevelBar({super.key, required this.xp});

  @override
  Widget build(BuildContext context) {
    final lvl = Progress.levelOf(xp);
    final next = Progress.xpAtLevel(lvl + 1);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Gx.goldGradient,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Gx.gold.withOpacity(0.5), blurRadius: 14)],
          ),
          child: Text('$lvl', style: Gx.display(22, color: Colors.black)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('LEVEL $lvl', style: Gx.display(13, color: Gx.goldLight)),
              const SizedBox(width: 8),
              Text(Progress.title(lvl), style: Gx.label(size: 12)),
              const Spacer(),
              Text('$xp / $next XP', style: Gx.label(size: 11)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: Progress.fraction(xp)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: Gx.bg, color: Gx.gold),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// 7-day streak strip with a claim button. All amounts are demo coins.
class DailyRewardCard extends StatelessWidget {
  final DailyStatus status;
  final VoidCallback onClaim;
  const DailyRewardCard({super.key, required this.status, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: !status.claimedToday,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.card_giftcard, color: Gx.gold),
          const SizedBox(width: 8),
          Text('DAILY REWARD', style: Gx.display(13)),
          const Spacer(),
          if (status.streak > 0) MiniTag('${status.streak} DAY STREAK'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: i < status.doneCount ? Gx.gold : Gx.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (!status.claimedToday && i == status.nextDay - 1) ? Gx.goldLight : Gx.line, width: (!status.claimedToday && i == status.nextDay - 1) ? 2 : 1),
                ),
                child: Column(children: [
                  Text('D${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i < status.doneCount ? Colors.black : Gx.muted)),
                  const SizedBox(height: 3),
                  Icon(i < status.doneCount ? Icons.check_circle : Icons.monetization_on, size: 16, color: i < status.doneCount ? Colors.black : Gx.goldLight),
                  const SizedBox(height: 2),
                  Text('${Progress.dailyAmounts[i]}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: i < status.doneCount ? Colors.black : Gx.text)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        GoldButton(
          label: status.claimedToday ? 'COME BACK TOMORROW' : 'CLAIM ${Progress.dailyAmounts[status.nextDay - 1]} COINS',
          icon: status.claimedToday ? Icons.check : Icons.redeem,
          compact: true,
          onPressed: status.claimedToday ? null : onClaim,
        ),
      ]),
    );
  }
}

class AchievementsGrid extends StatelessWidget {
  final UserProfile profile;
  const AchievementsGrid({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final done = kAchievements.where((a) => a.done(profile)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('$done / ${kAchievements.length} unlocked', style: Gx.label(size: 12)),
      ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final a in kAchievements)
            Builder(builder: (context) {
              final ok = a.done(profile);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ok ? Gx.gold.withOpacity(0.16) : Gx.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ok ? Gx.gold : Gx.line),
                ),
                child: Row(children: [
                  Icon(ok ? a.icon : Icons.lock_outline, color: ok ? Gx.gold : Gx.muted, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: ok ? Gx.text : Gx.muted)),
                      Text(a.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Gx.muted, height: 1.2)),
                    ]),
                  ),
                ]),
              );
            }),
        ],
      ),
    ]);
  }
}

/// One-shot confetti burst for victories.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = Random(7);
    _pieces = List.generate(70, (_) => _Piece(r));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)));
  }
}

class _Piece {
  final double x, delay, speed, size, spin, sway;
  final Color color;
  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.35,
        speed = 0.55 + r.nextDouble() * 0.6,
        size = 6 + r.nextDouble() * 7,
        spin = r.nextDouble() * 6,
        sway = (r.nextDouble() - 0.5) * 0.25,
        color = [Gx.seat[0], Gx.seat[1], Gx.seat[2], Gx.seat[3], Gx.goldLight, Colors.white][r.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = p.x * size.width + sin(local * 6 + p.spin) * size.width * p.sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * 8 + p.spin);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), Paint()..color = p.color.withOpacity((1 - local * 0.5).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
