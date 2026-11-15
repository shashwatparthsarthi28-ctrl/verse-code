import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/dialogs.dart';
import '../widgets/ludo_art.dart';
import '../widgets/progress_widgets.dart';
import 'leaderboard_screen.dart';
import 'mode_screens.dart';
import 'profile_screen.dart';
import 'select_mode_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'wallet_screen.dart';

/// The Ludo X main menu: logo, four big play buttons, side shortcuts and the
/// Profile / Statistics / Leaderboards / Settings pills.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DailyStatus? _daily;

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    _load();
  }

  @override
  void dispose() {
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await app.refresh();
    try {
      final d = await app.backend.getDaily();
      if (mounted) setState(() => _daily = d);
    } catch (_) {}
  }

  Future<void> _freeCoins() async {
    final amt = await askAmount(context,
        title: 'Free demo coins',
        hint: 'Amount (demo)',
        confirm: 'ADD',
        quick: const [100, 500, 1000, 5000],
        max: app.config.maxDemoDeposit);
    if (amt == null) return;
    try {
      await app.backend.demoDeposit(amt);
      Sfx.play('coin');
      await _load();
      if (mounted) toast(context, 'Added ${inr(amt)} (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _claimDaily() async {
    try {
      final amt = await app.backend.claimDaily();
      Sfx.play('coin');
      await _load();
      if (mounted) toast(context, 'Daily reward: +${inr(amt.toDouble())} (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _openDaily() async {
    try {
      final d = await app.backend.getDaily();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: DailyRewardCard(
            status: d,
            onClaim: () {
              Navigator.pop(ctx);
              _claimDaily();
            },
          ),
        ),
      );
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  void _soon(String what) => toast(context, '$what is coming soon');

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    if (p == null) return const SizedBox();
    final lvl = Progress.levelOf(p.xp);
    final dailyReady = _daily != null && !_daily!.claimedToday;
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _go(const ProfileScreen()),
                child: Row(children: [
                  AvatarView(index: p.avatar, size: 50),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.username, style: Gx.display(16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('Lv.$lvl', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Gx.goldLight)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: Progress.fraction(p.xp), minHeight: 7, backgroundColor: Colors.black.withOpacity(0.35), color: Gx.gold),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            CoinPill(value: app.balance, onAdd: () => _go(const WalletScreen())),
          ]),
          const SizedBox(height: 6),
          const LudoLogoHero(),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 76,
              height: 252,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _SideItem(
                  label: 'Daily\nRewards',
                  dot: dailyReady,
                  icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF5470), size: 30),
                  onTap: _openDaily,
                ),
                _SideItem(label: 'Free\nCoins', icon: const CrownIcon(size: 32), onTap: _freeCoins),
              ]),
            ),
            Expanded(
              child: SizedBox(
                height: 252,
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  ChunkyButton(
                    label: 'Competitive',
                    icon: Icons.emoji_events_rounded,
                    palette: Gx.yellow,
                    textColor: Gx.ink,
                    height: 54,
                    chevron: true,
                    onTap: () => _go(const CompetitiveScreen()),
                  ),
                  ChunkyButton(
                    label: 'Pro Challenge',
                    icon: Icons.smart_toy_rounded,
                    palette: Gx.green,
                    height: 54,
                    chevron: true,
                    onTap: () => _go(const ProBotScreen()),
                  ),
                  ChunkyButton(
                    label: 'Vs Computer',
                    icon: Icons.desktop_windows_rounded,
                    palette: Gx.blue,
                    height: 54,
                    chevron: true,
                    onTap: () => _go(const SelectModeScreen()),
                  ),
                  ChunkyButton(
                    label: 'Pass N Play',
                    icon: Icons.groups_rounded,
                    palette: Gx.purple,
                    height: 54,
                    chevron: true,
                    onTap: () => _go(const SelectModeScreen(local: true)),
                  ),
                ]),
              ),
            ),
            SizedBox(
              width: 76,
              height: 252,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _SideItem(
                  label: 'Tournament',
                  icon: const Icon(Icons.emoji_events_rounded, color: Gx.goldLight, size: 32),
                  onTap: () => _soon('Tournament'),
                ),
                _SideItem(
                  label: 'Shop',
                  icon: const Icon(Icons.storefront_rounded, color: Color(0xFFFF7A7A), size: 32),
                  onTap: () => _go(const WalletScreen()),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _Pill(icon: Icons.person_rounded, label: 'Profile', onTap: () => _go(const ProfileScreen()))),
            const SizedBox(width: 8),
            Expanded(child: _Pill(icon: Icons.bar_chart_rounded, label: 'Statistics', onTap: () => _go(const StatisticsScreen()))),
            const SizedBox(width: 8),
            Expanded(child: _Pill(icon: Icons.emoji_events_rounded, label: 'Leaderboards', onTap: () => _go(const LeaderboardScreen()))),
            const SizedBox(width: 8),
            Expanded(child: _Pill(icon: Icons.settings_rounded, label: 'Settings', dot: app.unread > 0, onTap: () => _go(const SettingsScreen()))),
          ]),
          const SizedBox(height: 14),
          const SimBanner(compact: true),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool dot;
  const _SideItem({required this.label, required this.icon, required this.onTap, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFF2E5FE0), Color(0xFF0B2A8C)], center: Alignment(-0.3, -0.4)),
              border: Border.all(color: Gx.goldLight, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 3), blurRadius: 4)],
            ),
            child: icon,
          ),
          if (dot)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: Gx.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ]),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 1.5), blurRadius: 2)],
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dot;
  const _Pill({required this.icon, required this.label, required this.onTap, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14389E), Color(0xFF0A1F6B)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Gx.gold, width: 1.6),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 3), blurRadius: 3)],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Gx.goldLight, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
          if (dot)
            Positioned(
              right: 6,
              top: 5,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: Gx.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- shared tiles
// (used by Statistics, Profile history, the Leaderboard and match history)

class MatchTile extends StatelessWidget {
  final MatchRecord record;
  const MatchTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final win = record.rank == 1;
    final paid = record.entry > 0;
    final net = record.net;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (win ? Gx.gold : Gx.navy),
              border: Border.all(color: win ? Colors.white : Gx.line, width: 1.5),
            ),
            child: Text(ordinal(record.rank), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: win ? Gx.ink : Gx.text)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(modeTitleOf(record.mode), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${timeAgo(record.ts)}${record.completed ? '' : '  |  abandoned'}${record.difficulty.isNotEmpty && record.difficulty != '-' ? '  |  ${record.difficulty}' : ''}',
                  style: Gx.label(size: 11), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(paid ? inr(net, sign: true) : 'Free',
              style: TextStyle(fontWeight: FontWeight.w900, color: !paid ? Gx.muted : (net >= 0 ? Gx.good : Gx.bad))),
        ]),
      ),
    );
  }
}

/// Mode names shown in lists (kept here so history tiles do not depend on the game screen).
String modeTitleOf(String mode) {
  switch (mode) {
    case 'practice':
      return 'Vs Computer';
    case 'competitive':
      return 'Competitive';
    default:
      return 'Pro Challenge';
  }
}

class LeaderTile extends StatelessWidget {
  final int rank;
  final LeaderEntry entry;
  final bool me;
  const LeaderTile({super.key, required this.rank, required this.entry, this.me = false});

  @override
  Widget build(BuildContext context) {
    const medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFCD7F32)];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        glow: me,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: rank <= 3 ? Icon(Icons.workspace_premium, color: medals[rank - 1]) : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.muted)),
          ),
          AvatarView(index: entry.avatar, size: 38, ring: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                if (me) ...[const SizedBox(width: 6), const MiniTag('YOU')],
                if (entry.sample) ...[const SizedBox(width: 6), const MiniTag('SAMPLE', color: Gx.muted)],
              ]),
              Text('${entry.wins} wins', style: Gx.label(size: 11)),
            ]),
          ),
          Text(inr(entry.earnings, sign: true), style: TextStyle(fontWeight: FontWeight.w900, color: entry.earnings >= 0 ? Gx.goldLight : Gx.bad)),
        ]),
      ),
    );
  }
}
