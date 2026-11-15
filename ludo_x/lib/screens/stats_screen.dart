import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/ludo_art.dart';
import '../widgets/progress_widgets.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';

/// Statistics: totals, level, achievements and recent matches
/// (this is the detailed part that used to live on the Profile tab).
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<MatchRecord> _history = [];

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
      final h = await app.backend.getHistory();
      if (mounted) setState(() => _history = h);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          GxTopBar(onAddCoins: () => openShop(context)),
          const TitleRibbon('Statistics'),
          const SizedBox(height: 8),
          Expanded(
            child: p == null
                ? const SizedBox()
                : RefreshIndicator(
                    color: Gx.gold,
                    backgroundColor: Gx.card,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            StatTile(label: 'Games played', value: '${p.played}', icon: Icons.sports_esports),
                            StatTile(label: 'Wins', value: '${p.wins}', icon: Icons.emoji_events, valueColor: Gx.goldLight),
                            StatTile(label: 'Losses', value: '${p.losses}', icon: Icons.heart_broken),
                            StatTile(label: 'Win rate', value: pct(p.winRate), icon: Icons.percent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        StatTile(label: 'Total simulated earnings (net)', value: inr(p.earnings, sign: true), icon: Icons.savings, valueColor: p.earnings >= 0 ? Gx.good : Gx.bad),
                        const SizedBox(height: 6),
                        Text('Stats count entry-fee matches only; Vs Computer games are excluded.', style: Gx.label(size: 11)),
                        const SectionHeader('Level'),
                        LevelBar(xp: p.xp),
                        const SectionHeader('Achievements'),
                        AchievementsGrid(profile: p),
                        SectionHeader('Match history',
                            action: _history.isEmpty ? null : 'See all',
                            onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()))),
                        if (_history.isEmpty)
                          AppCard(child: Text('No matches yet.', style: Gx.label(size: 13)))
                        else
                          for (final m in _history.take(5)) MatchTile(record: m),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
