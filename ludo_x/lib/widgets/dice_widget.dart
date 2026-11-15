import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated die. The value is whatever the SERVER rolled; while [rolling] the
/// parent feeds random faces purely for the animation.
class DiceView extends StatefulWidget {
  final int value; // 1..6, 0 = not rolled yet
  final bool rolling;
  final bool enabled; // human may roll now
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const DiceView({
    super.key,
    required this.value,
    required this.rolling,
    required this.enabled,
    required this.color,
    this.size = 84,
    this.onTap,
  });

  @override
  State<DiceView> createState() => _DiceViewState();
}

class _DiceViewState extends State<DiceView> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    if (widget.rolling) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant DiceView old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _spin.repeat();
    } else if (!widget.rolling && old.rolling) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (context, _) {
          final glow = widget.enabled ? 0.25 + 0.5 * _pulse.value : 0.0;
          final angle = widget.rolling ? _spin.value * 2 * math.pi : 0.0;
          final bounce = widget.rolling ? 1.0 + 0.08 * math.sin(_spin.value * 2 * math.pi * 2) : 1.0;
          return Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: bounce,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s * 0.2),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFF6), Color(0xFFE4DCC4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: widget.enabled ? Gx.goldLight : widget.color, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(0, 4)),
                    if (widget.enabled) BoxShadow(color: Gx.gold.withOpacity(glow), blurRadius: 24, spreadRadius: 3),
                  ],
                ),
                child: widget.value == 0
                    ? Center(child: Icon(Icons.casino, size: s * 0.5, color: Colors.black38))
                    : CustomPaint(painter: _PipPainter(widget.value)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int value;
  const _PipPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF151515);
    final w = size.width;
    final r = w * 0.085;
    Offset at(double fx, double fy) => Offset(w * fx, w * fy);
    final l = 0.27, c = 0.5, h = 0.73;
    final tl = at(l, l), tr = at(h, l), ml = at(l, c), mr = at(h, c), bl = at(l, h), br = at(h, h), mid = at(c, c);
    final List<Offset> pips;
    switch (value) {
      case 1:
        pips = [mid];
        break;
      case 2:
        pips = [tl, br];
        break;
      case 3:
        pips = [tl, mid, br];
        break;
      case 4:
        pips = [tl, tr, bl, br];
        break;
      case 5:
        pips = [tl, tr, mid, bl, br];
        break;
      default:
        pips = [tl, tr, ml, mr, bl, br];
    }
    for (final o in pips) {
      canvas.drawCircle(o, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) => old.value != value;
}
