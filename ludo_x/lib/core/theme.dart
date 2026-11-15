import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sound.dart';

/// Top / bottom colour + the dark "edge" used for the chunky 3D buttons.
class GxPalette {
  final Color top;
  final Color bottom;
  final Color edge;
  const GxPalette(this.top, this.bottom, this.edge);
}

/// LUDO X design tokens: royal-blue arena, glossy candy buttons, gold accents.
class Gx {
  static const Color bg = Color(0xFF0B2A96);
  static const Color bgTop = Color(0xFF1B52E8);
  static const Color bgBottom = Color(0xFF071C70);
  static const Color navy = Color(0xFF0A1F6B);
  static const Color surface = Color(0xFF102F9E);
  static const Color card = Color(0xFF1A3FB4);
  static const Color cardHi = Color(0xFF2A57D6);
  static const Color line = Color(0xFF5B86F5);
  static const Color gold = Color(0xFFFFC21A);
  static const Color goldLight = Color(0xFFFFE066);
  static const Color goldDark = Color(0xFFFF9500);
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFB9CBFF);
  static const Color good = Color(0xFF3DDC84);
  static const Color bad = Color(0xFFFF5470);
  static const Color ink = Color(0xFF14246E); // dark text on bright buttons

  // Seat colours, clockwise from top-left (same positions as the Ludo X board art).
  static const List<Color> seat = [Color(0xFF2FB84A), Color(0xFFFFC91F), Color(0xFF2B7BFF), Color(0xFFE8363D)];
  static const List<String> seatName = ['Green', 'Yellow', 'Blue', 'Red'];

  static const GxPalette yellow = GxPalette(Color(0xFFFFD84A), Color(0xFFFF9E0B), Color(0xFFB36200));
  static const GxPalette green = GxPalette(Color(0xFF5BE06A), Color(0xFF1FA032), Color(0xFF0C6A1B));
  static const GxPalette blue = GxPalette(Color(0xFF45A9FF), Color(0xFF1B5FE6), Color(0xFF0C3B9E));
  static const GxPalette purple = GxPalette(Color(0xFFC36BFF), Color(0xFF6E2BE3), Color(0xFF3E1599));
  static const GxPalette red = GxPalette(Color(0xFFFF7A7A), Color(0xFFE02D3C), Color(0xFF8F1020));

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle display(double size, {Color color = text}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: color, height: 1.1);

  static TextStyle label({Color color = muted, double size = 12}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: color);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Colors.black,
        secondary: goldLight,
        surface: surface,
        onSurface: text,
        error: bad,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: text,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: text),
      ),
      cardTheme: CardThemeData(color: card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF10309F),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: line, width: 1.5)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navy.withOpacity(0.55),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
      ),
      dividerColor: line.withOpacity(0.5),
    );
  }
}

// ---------------------------------------------------------------- formatting

String _group(String digits) {
  final sb = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
    sb.write(digits[i]);
  }
  return sb.toString();
}

String _num(double a) {
  final whole = (a - a.roundToDouble()).abs() < 0.005;
  final s = whole ? a.round().toString() : a.toStringAsFixed(2);
  final parts = s.split('.');
  return '${_group(parts[0])}${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Plain number with thousands separators, e.g. 25760 -> "25,760" (used in the coin pill).
String coinNum(double v) => _num(v.abs());

/// Formats a (simulated) coin amount, e.g. 1234.5 -> "1,234.50 coins", 160 -> "160 coins".
/// (Name kept from the original code so every screen keeps working.)
String inr(double v, {bool sign = false}) {
  final out = '${_num(v.abs())} coins';
  if (v < 0) return '-$out';
  return sign && v > 0 ? '+$out' : out;
}

String pct(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

String ordinal(int n) {
  switch (n) {
    case 1:
      return '1st';
    case 2:
      return '2nd';
    case 3:
      return '3rd';
    default:
      return '${n}th';
  }
}

String timeAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.day}/${t.month}/${t.year}';
}

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Gx.bad : Gx.gold, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg)),
    ]),
  ));
}

// ---------------------------------------------------------------- background + scaffold

/// Royal-blue gradient with faint tumbling dice, like the Ludo X art.
class LudoBackground extends StatelessWidget {
  const LudoBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Gx.bgTop, Gx.bg, Gx.bgBottom],
        ),
      ),
      child: CustomPaint(painter: _PatternPainter(), size: Size.infinite),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // soft light behind the logo area
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.16), Colors.white.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.22), radius: size.width * 0.8));
    canvas.drawRect(Offset.zero & size, glow);

    final rnd = math.Random(11);
    final fill = Paint()..color = Colors.white.withOpacity(0.045);
    final pip = Paint()..color = Colors.white.withOpacity(0.07);
    final count = 16;
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final s = 34 + rnd.nextDouble() * 40;
      final a = (rnd.nextDouble() - 0.5) * 1.2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s), Radius.circular(s * 0.2)), fill);
      final pips = 1 + rnd.nextInt(6);
      final o = s * 0.24;
      final spots = <Offset>[
        Offset(-o, -o), Offset(o, o), Offset(0, 0), Offset(o, -o), Offset(-o, o), Offset(-o, 0),
      ];
      for (var k = 0; k < pips; k++) {
        canvas.drawCircle(spots[k], s * 0.07, pip);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scaffold that paints the Ludo X background itself, so every route is opaque
/// (no see-through pages during transitions).
class GxScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  const GxScaffold({super.key, this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const LudoBackground(),
        Scaffold(backgroundColor: Colors.transparent, appBar: appBar, body: body),
      ],
    );
  }
}

// ---------------------------------------------------------------- buttons

/// Glossy 3D candy button (the Ludo X menu buttons).
class ChunkyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final GxPalette palette;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool chevron;
  final bool loading;
  final Color textColor;
  final String? badge;

  const ChunkyButton({
    super.key,
    required this.label,
    required this.palette,
    this.onTap,
    this.icon,
    this.leading,
    this.height = 56,
    this.fontSize = 18,
    this.chevron = false,
    this.loading = false,
    this.textColor = Colors.white,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final radius = BorderRadius.circular(height * 0.34);
    final shadows = textColor == Colors.white
        ? <Shadow>[Shadow(color: Colors.black.withOpacity(0.4), offset: const Offset(0, 2), blurRadius: 2)]
        : <Shadow>[];
    Widget? lead;
    if (loading) {
      lead = SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.6, color: textColor));
    } else if (leading != null) {
      lead = leading;
    } else if (icon != null) {
      lead = Icon(icon, size: height * 0.5, color: textColor);
    }
    return Opacity(
      opacity: (onTap != null) ? 1 : 0.5,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.top, palette.bottom]),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(color: palette.edge, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(children: [
            Positioned(
              left: 8,
              right: 8,
              top: 3,
              height: height * 0.36,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height * 0.2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          Sfx.play('tap');
                          onTap!();
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      if (lead != null) ...[SizedBox(width: height * 0.6, child: Center(child: lead)), const SizedBox(width: 6)],
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.3, shadows: shadows),
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(8)),
                          child: Text(badge!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                        )
                      else if (chevron)
                        Icon(Icons.chevron_right_rounded, size: height * 0.62, color: textColor),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Primary action button (yellow candy) or outlined secondary button.
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final bool compact;
  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final h = compact ? 42.0 : 54.0;
    if (!outlined) {
      return ChunkyButton(
        label: label,
        icon: icon,
        palette: Gx.yellow,
        height: h,
        fontSize: compact ? 13.5 : 16,
        textColor: Gx.ink,
        loading: loading,
        onTap: onPressed,
      );
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(h * 0.34),
          border: Border.all(color: Gx.goldLight, width: 1.6),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(h * 0.34),
            onTap: enabled
                ? () {
                    Sfx.play('tap');
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (loading)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Gx.goldLight))
                  else if (icon != null)
                    Icon(icon, size: compact ? 18 : 20, color: Gx.goldLight),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: compact ? 13 : 15, color: Gx.goldLight)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shared widgets

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.glow = false, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Gx.cardHi.withOpacity(0.85), Gx.card],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? (glow ? Gx.gold : Gx.line.withOpacity(0.7)), width: glow ? 2 : 1.3),
        boxShadow: [
          BoxShadow(color: Gx.navy.withOpacity(0.9), offset: const Offset(0, 3)),
          if (glow) BoxShadow(color: Gx.gold.withOpacity(0.28), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(gradient: Gx.goldGradient, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(title.toUpperCase(), style: Gx.display(14))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: Gx.goldLight, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
      ]),
    );
  }
}

const List<IconData> _avatarIcons = [
  Icons.sports_esports, Icons.rocket_launch, Icons.local_fire_department, Icons.bolt,
  Icons.diamond, Icons.shield, Icons.star, Icons.pets,
  Icons.psychology, Icons.sports_martial_arts, Icons.emoji_events, Icons.casino,
];
const List<List<Color>> _avatarColors = [
  [Color(0xFFF6D77A), Color(0xFF8C6D1F)], [Color(0xFFFF8A65), Color(0xFFB71C1C)], [Color(0xFFFFB74D), Color(0xFFE65100)],
  [Color(0xFFFFF176), Color(0xFFF9A825)], [Color(0xFF80DEEA), Color(0xFF00838F)], [Color(0xFF90CAF9), Color(0xFF1565C0)],
  [Color(0xFFCE93D8), Color(0xFF6A1B9A)], [Color(0xFFA5D6A7), Color(0xFF2E7D32)], [Color(0xFFF48FB1), Color(0xFFAD1457)],
  [Color(0xFFBCAAA4), Color(0xFF4E342E)], [Color(0xFFFFE082), Color(0xFFFF8F00)], [Color(0xFFB0BEC5), Color(0xFF37474F)],
];
const int kAvatarCount = 12;

class AvatarView extends StatelessWidget {
  final int index;
  final double size;
  final bool ring;
  const AvatarView({super.key, required this.index, this.size = 48, this.ring = true});

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, kAvatarCount - 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: _avatarColors[i], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: ring ? Border.all(color: Gx.gold, width: size > 60 ? 3.5 : 2.5) : null,
        boxShadow: ring ? [BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 3), blurRadius: 4)] : null,
      ),
      child: Icon(_avatarIcons[i], color: Colors.black87, size: size * 0.5),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  const StatTile({super.key, required this.label, required this.value, this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: Gx.goldLight), const SizedBox(width: 6)],
          Expanded(child: Text(label.toUpperCase(), style: Gx.label(size: 10.5), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Gx.display(22, color: valueColor ?? Gx.text)),
        ),
      ]),
    );
  }
}

/// Always-visible reminder that no real money is involved.
class SimBanner extends StatelessWidget {
  final bool compact;
  const SimBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Gx.navy.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Gx.gold.withOpacity(0.45)),
      ),
      child: Row(children: [
        const Icon(Icons.science_outlined, size: 16, color: Gx.goldLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            compact
                ? 'SIMULATED COINS - no real money'
                : 'Simulated-coin prototype. No real money is deposited, withdrawn or won. Real payments are disabled.',
            style: const TextStyle(fontSize: 11.5, color: Gx.goldLight, fontWeight: FontWeight.w700, height: 1.3),
          ),
        ),
      ]),
    );
  }
}

class MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const MiniTag(this.text, {super.key, this.color = Gx.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: color)),
    );
  }
}
