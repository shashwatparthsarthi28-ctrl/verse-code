import 'package:flutter/material.dart';

import '../core/sound.dart';
import '../core/theme.dart';
import '../widgets/ludo_art.dart';
import 'game_screen.dart';
import 'pass_play_screen.dart';
import 'wallet_screen.dart';

/// "Select Game Mode" (Ludo X design). The rules engine plays 4-seat Classic
/// Ludo, so those tiles are live; the other tiles are shown locked.
class SelectModeScreen extends StatefulWidget {
  /// true = Pass N Play (2-4 humans on one phone), false = Vs Computer.
  final bool local;
  const SelectModeScreen({super.key, this.local = false});

  @override
  State<SelectModeScreen> createState() => _SelectModeScreenState();
}

class _SelectModeScreenState extends State<SelectModeScreen> {
  int _players = 4;
  String _style = 'classic';

  void _locked(String what) {
    Sfx.play('tap');
    toast(context, '$what is coming soon. Classic Ludo is available now.');
  }

  @override
  Widget build(BuildContext context) {
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          GxTopBar(onAddCoins: () => openShop(context)),
          const TitleRibbon('Select Game Mode'),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Row(children: [
                  Expanded(child: _playersTile(2, [Gx.seat[2], Gx.seat[3]])),
                  const SizedBox(width: 12),
                  Expanded(child: _playersTile(3, [Gx.seat[2], Gx.seat[3], Gx.seat[0]])),
                  const SizedBox(width: 12),
                  Expanded(child: _playersTile(4, [Gx.seat[2], Gx.seat[3], Gx.seat[0], Gx.seat[1]])),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _styleTile('quick', 'Quick\nLudo', Icons.bolt_rounded, const Color(0xFF2FB84A), const Color(0xFF117A29))),
                  const SizedBox(width: 12),
                  Expanded(child: _styleTile('classic', 'Classic\nLudo', Icons.workspace_premium_rounded, const Color(0xFF2B6BFF), const Color(0xFF123FB0))),
                  const SizedBox(width: 12),
                  Expanded(child: _playersTile(6, [Gx.seat[3], Gx.seat[0], Gx.seat[2], Gx.seat[1], Gx.seat[3], Gx.seat[0]])),
                ]),
                const SizedBox(height: 26),
                ChunkyButton(
                  label: widget.local ? 'START $_players PLAYERS' : 'PLAY VS COMPUTER',
                  icon: Icons.play_arrow_rounded,
                  palette: widget.local ? Gx.purple : Gx.green,
                  height: 60,
                  fontSize: 19,
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                      builder: (_) => widget.local ? PassPlayScreen(players: _players) : const GameScreen(mode: 'practice'))),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.local
                      ? 'Pass the phone between 2-4 friends. Free game, no coins charged or won.'
                      : 'Free game against 3 AI bots. No coins are charged and none are won.',
                  textAlign: TextAlign.center,
                  style: Gx.label(size: 12),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tileBox({required Widget child, required bool selected, required bool locked, required VoidCallback onTap, Color? top, Color? bottom}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top ?? const Color(0xFF2B55C8), bottom ?? const Color(0xFF173C9E)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Gx.goldLight : Gx.line, width: selected ? 3 : 1.6),
          boxShadow: [
            BoxShadow(color: Gx.navy.withOpacity(0.9), offset: const Offset(0, 4)),
            if (selected) BoxShadow(color: Gx.gold.withOpacity(0.55), blurRadius: 18),
          ],
        ),
        child: Stack(children: [
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(8), child: child)),
          if (locked)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_rounded, size: 10, color: Gx.goldLight),
                  SizedBox(width: 3),
                  Text('SOON', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Gx.goldLight, letterSpacing: 0.5)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _playersTile(int n, List<Color> colors) {
    final live = widget.local ? n <= 4 : n == 4;
    return _tileBox(
      selected: live && _players == n,
      locked: !live,
      onTap: live
          ? () {
              Sfx.play('tap');
              setState(() => _players = n);
            }
          : () => _locked('$n Players'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$n', style: Gx.display(30)),
        Text('Players', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          children: [for (final c in colors) PawnIcon(color: c, size: n == 6 ? 20 : 28)],
        ),
      ]),
    );
  }

  Widget _styleTile(String id, String label, IconData icon, Color top, Color bottom) {
    final live = id == 'classic';
    return _tileBox(
      top: top,
      bottom: bottom,
      selected: live && _style == id,
      locked: !live,
      onTap: live
          ? () {
              Sfx.play('tap');
              setState(() => _style = id);
            }
          : () => _locked('Quick Ludo'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        id == 'classic' ? const CrownIcon(size: 44) : Icon(icon, size: 46, color: Gx.goldLight),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w900, color: Colors.white)),
      ]),
    );
  }
}
