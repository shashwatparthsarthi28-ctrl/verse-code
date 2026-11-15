import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import 'board_widget.dart' show PawnPainter;

// ------------------------------------------------------------------ coin

Path _starPath(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  return path;
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * 0.94;
    canvas.drawCircle(c + Offset(0, r * 0.1), r, Paint()..color = const Color(0xFFB36200));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF59D), Color(0xFFFFC21A), Color(0xFFFF9500)],
          stops: [0.0, 0.6, 1.0],
          center: Alignment(-0.3, -0.4),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
        c,
        r * 0.74,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..color = const Color(0xFFE08A00));
    canvas.drawPath(_starPath(c, r * 0.46), Paint()..color = const Color(0xFFE08A00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: const CustomPaint(painter: _CoinPainter()));
}

/// Coin balance pill with the green "+" button (top-right of every Ludo X screen).
class CoinPill extends StatelessWidget {
  final double value;
  final VoidCallback? onAdd;
  const CoinPill({super.key, required this.value, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: const Color(0x99061A66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const CoinIcon(size: 26),
        const SizedBox(width: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(coinNum(v), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              Sfx.play('tap');
              onAdd!();
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF2DC653),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ] else
          const SizedBox(width: 8),
      ]),
    );
  }
}

// ------------------------------------------------------------------ round buttons / bars

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4F8BFF), Color(0xFF1B4FD8)]),
          border: Border.all(color: Colors.white, width: 2.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 3), blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).maybePop());
  }
}

/// Back button + small LUDO X wordmark + coin pill.
class GxTopBar extends StatelessWidget {
  final bool back;
  final VoidCallback? onAddCoins;
  const GxTopBar({super.key, this.back = true, this.onAddCoins});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [
          if (back) const RoundBackButton() else const SizedBox(width: 42),
          const SizedBox(width: 10),
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: LudoWordmark(size: 24))),
          AnimatedBuilder(animation: app, builder: (_, __) => CoinPill(value: app.balance, onAdd: onAddCoins)),
        ]),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(h * 0.5, 0)
      ..lineTo(w - h * 0.5, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w - h * 0.5, h)
      ..lineTo(h * 0.5, h)
      ..lineTo(0, h * 0.5)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black.withOpacity(0.35));
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF123A9E), Color(0xFF071C6A)])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = Gx.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dark navy ribbon with gold outline used as screen title.
class TitleRibbon extends StatelessWidget {
  final String text;
  const TitleRibbon(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _RibbonPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 9),
        child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
      ),
    );
  }
}

// ------------------------------------------------------------------ pawn / crown / die

class PawnIcon extends StatelessWidget {
  final Color color;
  final double size;
  const PawnIcon({super.key, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: PawnPainter(color: color, highlight: false)));
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.08, h * 0.88)
      ..lineTo(w * 0.02, h * 0.28)
      ..lineTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.98, h * 0.28)
      ..lineTo(w * 0.92, h * 0.88)
      ..close();
    canvas.drawPath(body.shift(Offset(0, h * 0.04)), Paint()..color = const Color(0xFFB36200));
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF176), Color(0xFFFFB300)])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFD97E00));
    final band = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.74, w * 0.84, h * 0.15), Radius.circular(h * 0.05));
    canvas.drawRRect(band, Paint()..color = const Color(0xFFFFA000));
    final ball = Paint()..color = const Color(0xFFFFF59D);
    canvas.drawCircle(Offset(w * 0.02, h * 0.26), w * 0.06, ball);
    canvas.drawCircle(Offset(w * 0.5, h * 0.1), w * 0.065, ball);
    canvas.drawCircle(Offset(w * 0.98, h * 0.26), w * 0.06, ball);
    canvas.drawCircle(Offset(w * 0.5, h * 0.58), w * 0.075, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(Offset(w * 0.5 - w * 0.02, h * 0.58 - h * 0.02), w * 0.025, Paint()..color = Colors.white.withOpacity(0.8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CrownIcon extends StatelessWidget {
  final double size;
  const CrownIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size * 0.85, child: const CustomPaint(painter: _CrownPainter()));
}

class _DiePainter extends CustomPainter {
  final int value;
  const _DiePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, w), Radius.circular(w * 0.22));
    canvas.drawRRect(r.shift(Offset(0, w * 0.06)), Paint()..color = Colors.black.withOpacity(0.3));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFD9DFF2)])
            .createShader(Rect.fromLTWH(0, 0, w, w)),
    );
    final pip = Paint()..color = const Color(0xFF1B2A6B);
    final pr = w * 0.085;
    Offset at(double fx, double fy) => Offset(w * fx, w * fy);
    final l = 0.27, c = 0.5, h = 0.73;
    final List<Offset> pips;
    switch (value) {
      case 1:
        pips = [at(c, c)];
        break;
      case 2:
        pips = [at(l, l), at(h, h)];
        break;
      case 3:
        pips = [at(l, l), at(c, c), at(h, h)];
        break;
      case 4:
        pips = [at(l, l), at(h, l), at(l, h), at(h, h)];
        break;
      case 5:
        pips = [at(l, l), at(h, l), at(c, c), at(l, h), at(h, h)];
        break;
      default:
        pips = [at(l, l), at(h, l), at(l, c), at(h, c), at(l, h), at(h, h)];
    }
    for (final o in pips) {
      canvas.drawCircle(o, pr, pip);
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter old) => old.value != value;
}

class DieFace extends StatelessWidget {
  final double size;
  final int value;
  const DieFace({super.key, this.size = 48, this.value = 5});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _DiePainter(value)));
}

// ------------------------------------------------------------------ logo

Widget _outlinedText(String t, double fs, List<Color> fill) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = fs * 0.16
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF3B1D00);
  final style = TextStyle(fontSize: fs, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0);
  return Stack(clipBehavior: Clip.none, children: [
    Transform.translate(offset: Offset(0, fs * 0.09), child: Text(t, style: style.copyWith(foreground: stroke))),
    Text(t, style: style.copyWith(foreground: stroke)),
    ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill).createShader(r),
      child: Text(t, style: style.copyWith(color: Colors.white)),
    ),
  ]);
}

/// "LUDO" in gold with a big red "X".
class LudoWordmark extends StatelessWidget {
  final double size;
  const LudoWordmark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      _outlinedText('LUDO', size, const [Color(0xFFFFF59D), Color(0xFFFFB300)]),
      SizedBox(width: size * 0.08),
      _outlinedText('X', size * 1.25, const [Color(0xFFFF7A7A), Color(0xFFD81B2D)]),
    ]);
  }
}

/// Crown + wordmark + pawns + die: the big logo on the main menu and splash.
class LudoLogoHero extends StatelessWidget {
  const LudoLogoHero({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 300,
        height: 190,
        child: Stack(clipBehavior: Clip.none, children: [
          const Positioned(left: 0, right: 0, top: 54, child: Center(child: LudoWordmark(size: 58))),
          Positioned(left: 38, top: 12, child: PawnIcon(color: Gx.seat[2], size: 40)),
          Positioned(right: 38, top: 30, child: PawnIcon(color: Gx.seat[1], size: 36)),
          Positioned(left: 4, top: 74, child: PawnIcon(color: Gx.seat[3], size: 78)),
          Positioned(right: 4, top: 74, child: PawnIcon(color: Gx.seat[0], size: 78)),
          const Positioned(left: 108, top: 0, width: 84, child: Center(child: CrownIcon(size: 84))),
          const Positioned(left: 122, top: 126, child: DieFace(size: 56, value: 5)),
        ]),
      ),
    );
  }
}
