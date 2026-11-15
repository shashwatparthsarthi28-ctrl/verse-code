import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/ludo_art.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderEntry> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await app.backend.getLeaderboard();
      if (mounted) setState(() {
        _list = l;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = app.profile?.uid;
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          GxTopBar(onAddCoins: () => openShop(context)),
          const TitleRibbon('Leaderboards'),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: Gx.gold,
              backgroundColor: Gx.card,
              onRefresh: _load,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                Text('Ranked by wins, then simulated earnings (entry-fee matches only)', style: Gx.label(size: 12), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Gx.gold)))
                else if (_error != null)
                  AppCard(child: Text(_error!, style: const TextStyle(color: Gx.bad)))
                else ...[
                  if (_list.length >= 3) _Podium(list: _list.take(3).toList()),
                  const SizedBox(height: 14),
                  for (var i = 0; i < _list.length; i++) LeaderTile(rank: i + 1, entry: _list[i], me: _list[i].uid == me),
                  if (_list.any((e) => e.sample))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Rows tagged SAMPLE are fixed demo entries so the board is never empty in the local simulation.', style: Gx.label(size: 11)),
                    ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderEntry> list;
  const _Podium({required this.list});

  @override
  Widget build(BuildContext context) {
    Widget col(LeaderEntry e, int place, double h) {
      const colors = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFCD7F32)];
      return Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          AvatarView(index: e.avatar, size: place == 1 ? 64 : 52),
          const SizedBox(height: 6),
          Text(e.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text('${e.wins} wins', style: Gx.label(size: 11)),
          const SizedBox(height: 6),
          Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors[place - 1], colors[place - 1].withOpacity(0.25)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text('$place', style: Gx.display(24, color: Colors.black87)),
          ),
        ]),
      );
    }

    return SizedBox(
      height: 230,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [col(list[1], 2, 70), col(list[0], 1, 100), col(list[2], 3, 52)]),
    );
  }
}
