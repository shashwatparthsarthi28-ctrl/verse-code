import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import 'home_screen.dart';
import 'match_log_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MatchRecord> _list = [];
  bool _loading = true;
  String _mode = 'all';

  @override
  void initState() {
    super.initState();
    app.backend.getHistory().then((h) {
      if (mounted) setState(() {
        _list = h;
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _mode == 'all' ? _list : _list.where((m) => m.mode == _mode).toList();
    const modes = {'all': 'All', 'practice': 'Practice', 'competitive': 'Competitive', 'pro': 'Pro Bot'};
    return GxScaffold(
      appBar: AppBar(title: const Text('MATCH HISTORY')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Gx.gold))
          : ListView(padding: const EdgeInsets.all(16), children: [
              SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final e in modes.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value, style: TextStyle(fontWeight: FontWeight.w700, color: _mode == e.key ? Colors.black : Gx.muted)),
                        selected: _mode == e.key,
                        selectedColor: Gx.gold,
                        backgroundColor: Gx.card,
                        side: const BorderSide(color: Gx.line),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _mode = e.key),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                AppCard(child: Text('No matches in this category yet.', style: Gx.label(size: 13)))
              else
                for (final m in list)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchLogScreen(matchId: m.id))),
                    child: MatchTile(record: m),
                  ),
              if (list.isNotEmpty) Text('Tap a match to open its server log and verify the dice.', style: Gx.label(size: 11), textAlign: TextAlign.center),
            ]),
    );
  }
}
