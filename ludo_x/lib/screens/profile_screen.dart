import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/progress.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/ludo_art.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';
import 'wallet_screen.dart';

/// "My Profile" (Ludo X design): avatar, ID, level, quick stats and shortcuts.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    app.refresh();
  }

  @override
  void dispose() {
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final p = app.profile!;
    final name = TextEditingController(text: p.username);
    var avatar = p.avatar;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, maxLength: 16, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Avatar', style: Gx.label())),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < kAvatarCount; i++)
                  GestureDetector(
                    onTap: () => set(() => avatar = i),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: avatar == i ? Gx.goldLight : Colors.transparent, width: 2.5)),
                      child: AvatarView(index: i, size: 44, ring: false),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save', style: TextStyle(color: Gx.goldLight, fontWeight: FontWeight.w900))),
          ],
        );
      }),
    );
    if (ok != true) return;
    try {
      await app.backend.updateProfile(name.text, avatar);
      await app.refresh();
      if (mounted) toast(context, 'Profile updated');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  Widget _row(String l, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(l, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Gx.muted))),
          Text(v, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color ?? Colors.white)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          GxTopBar(onAddCoins: () => openShop(context)),
          const TitleRibbon('My Profile'),
          const SizedBox(height: 14),
          Expanded(child: p == null ? const SizedBox() : _body(p)),
        ]),
      ),
    );
  }

  Widget _body(UserProfile p) {
    final lvl = Progress.levelOf(p.xp);
    final uid = p.uid.length >= 6 ? p.uid.substring(0, 6).toUpperCase() : p.uid.toUpperCase();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Gx.navy.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Gx.gold, width: 2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              AvatarView(index: p.avatar, size: 96),
              const Positioned(right: -6, bottom: -6, child: CrownIcon(size: 36)),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: 100, child: ChunkyButton(label: 'Edit', icon: Icons.edit_rounded, palette: Gx.blue, height: 38, fontSize: 14, onTap: _edit)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.username, style: Gx.display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('ID: #LX$uid', style: Gx.label(size: 13)),
              const SizedBox(height: 2),
              Text(p.isGuest ? 'Guest account' : (p.email.isEmpty ? ' ' : p.email), style: Gx.label(size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text('Lv.$lvl', style: Gx.display(18, color: Gx.goldLight)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: Progress.fraction(p.xp), minHeight: 11, backgroundColor: Colors.black.withOpacity(0.35), color: Gx.gold),
              ),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: Text('${p.xp} / ${Progress.xpAtLevel(lvl + 1)} XP', style: Gx.label(size: 11, color: Colors.white))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        decoration: BoxDecoration(
          color: Gx.navy.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Gx.line, width: 1.6),
        ),
        child: Column(children: [
          _row('Total Games', '${p.played}'),
          const Divider(height: 1),
          _row('Win Rate', pct(p.winRate)),
          const Divider(height: 1),
          _row('Wins', '${p.wins}', color: Gx.goldLight),
          const Divider(height: 1),
          _row('Current Rank', Progress.title(lvl), color: Gx.goldLight),
        ]),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: ChunkyButton(label: 'Statistics', icon: Icons.bar_chart_rounded, palette: Gx.blue, height: 56, fontSize: 15, onTap: () => _push(const StatisticsScreen()))),
        const SizedBox(width: 12),
        Expanded(child: ChunkyButton(label: 'Leaderboard', icon: Icons.emoji_events_rounded, palette: Gx.yellow, textColor: Gx.ink, height: 56, fontSize: 15, onTap: () => _push(const LeaderboardScreen()))),
      ]),
    ]);
  }
}

/// Plain-language summary of the security model, as required for the prototype.
class FairPlayScreen extends StatelessWidget {
  const FairPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String b) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: Gx.goldLight),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(b, style: const TextStyle(color: Gx.muted, fontSize: 13, height: 1.35)),
                ]),
              ),
            ]),
          ),
        );
    return GxScaffold(
      appBar: AppBar(title: const Text('FAIR PLAY & SECURITY')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SimBanner(),
        const SizedBox(height: 14),
        item(Icons.casino, 'Server-authoritative dice', 'Dice are derived on the server from a secret seed. The app only sends "roll" and shows the result. Before roll #1 the server publishes sha256(seed); after the match it reveals the seed so you can verify every roll.'),
        item(Icons.lock, 'Secure match state', 'Match state, balances and ledgers cannot be written by the app. Firestore rules are read-only for clients and every change goes through Cloud Functions.'),
        item(Icons.account_balance_wallet, 'No client-side balance changes', 'Entry fees and rewards are applied by the server in one transaction when a match starts and ends.'),
        item(Icons.receipt_long, 'Match logs', 'Every roll, move, capture, skip and timeout is stored in a hash-chained log. Open it from the match screen or your history.'),
        item(Icons.gpp_good, 'Anti-cheat validation', 'The server rejects stale or replayed requests, out-of-turn actions, illegal tokens, too-fast actions and early timeouts, logs each violation and flags repeat offenders.'),
        item(Icons.smart_toy, 'Bots are always labelled', 'Every AI opponent shows an AI BOT tag with its difficulty and strategy. You are never matched with hidden bots and every opponent in this prototype is a bot.'),
        item(Icons.science, 'Simulated coins only', 'No real deposit, withdrawal or prize exists in this app. Real payments are disabled until legal and regulatory requirements are independently verified.'),
      ]),
    );
  }
}
