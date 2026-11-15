import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../widgets/ludo_art.dart';
import 'admin_screen.dart';
import 'calculator_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

/// Settings: sound, notifications, tools, fair-play info and sign out
/// (everything that used to sit in the "More" list of the Profile tab).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    app.addListener(_r);
  }

  @override
  void dispose() {
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your demo wallet and history stay saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out', style: TextStyle(color: Gx.bad, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    final nav = Navigator.of(context);
    await app.signOut();
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          GxTopBar(onAddCoins: () => openShop(context)),
          const TitleRibbon('Settings'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              _item(app.soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, app.soundOn ? 'Sound: on' : 'Sound: off', null, app.toggleSound),
              _item(Icons.notifications_rounded, 'Notifications', app.unread > 0 ? '${app.unread} new' : null, () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
                await app.refresh();
              }),
              _item(Icons.history_rounded, 'Match history', null, () => _push(const HistoryScreen())),
              _item(Icons.calculate_rounded, 'Payout calculator', null, () => _push(const CalculatorScreen())),
              if (p != null && p.isAdmin) _item(Icons.admin_panel_settings_rounded, 'Admin dashboard', null, () => _push(const AdminScreen())),
              _item(Icons.shield_rounded, 'Fair play & security', null, () => _push(const FairPlayScreen())),
              _item(Icons.logout_rounded, 'Sign out', null, _signOut, danger: true),
              const SizedBox(height: 14),
              const SimBanner(),
              const SizedBox(height: 10),
              Text('Backend: ${app.backend.label}', style: Gx.label(size: 11), textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _item(IconData i, String t, String? trailing, VoidCallback f, {bool danger = false}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: f,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(i, color: danger ? Gx.bad : Gx.goldLight, size: 24),
            const SizedBox(width: 14),
            Expanded(child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: danger ? Gx.bad : Gx.text))),
            if (trailing != null) MiniTag(trailing),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Gx.muted),
          ]),
        ),
      );
}
