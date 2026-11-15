import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/payout.dart';
import '../core/theme.dart';
import '../engine/bot_ai.dart';
import '../services/models.dart';
import '../widgets/payout_breakdown.dart';

/// Admin dashboard: platform statistics (simulated money) plus bot and match
/// configuration. Server-side, adminStats/adminSetConfig require an `admin` custom claim.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  AdminStats? _s;
  String? _error;
  bool _saving = false;

  final _entry = TextEditingController();
  final _tiers = TextEditingController();
  final _turn = TextEditingController();
  final List<TextEditingController> _mult = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _names = List.generate(3, (_) => TextEditingController());
  String _botDiff = 'medium';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_entry, _tiers, _turn, ..._mult, ..._names]) c.dispose();
    super.dispose();
  }

  String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _load() async {
    try {
      final s = await app.backend.getAdminStats();
      final c = s.config;
      _entry.text = _n(c.competitiveEntry);
      _tiers.text = c.proTiers.map(_n).join(', ');
      _turn.text = '${c.turnSeconds}';
      for (var i = 0; i < 4; i++) _mult[i].text = c.multipliers[i].toString();
      for (var i = 0; i < 3; i++) _names[i].text = i < c.botNames.length ? c.botNames[i] : 'Bot${i + 1}';
      _botDiff = c.competitiveBotDifficulty;
      if (mounted) setState(() {
        _s = s;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  PayoutConfig get _preview => PayoutConfig(entry: _d(_entry), multipliers: [for (final c in _mult) _d(c)]);

  Future<void> _save() async {
    final tiers = _tiers.text.split(',').map((e) => double.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
    final cfg = _s!.config.copyWith(
      competitiveEntry: _d(_entry),
      proTiers: tiers,
      multipliers: [for (final c in _mult) _d(c)],
      turnSeconds: int.tryParse(_turn.text.trim()) ?? 20,
      competitiveBotDifficulty: _botDiff,
      botNames: [for (final c in _names) c.text.trim().isEmpty ? 'Bot' : c.text.trim()],
    );
    if (!PayoutConfig(entry: cfg.competitiveEntry, multipliers: cfg.multipliers).isValid) {
      toast(context, 'Payouts exceed the pool. Lower a multiplier.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await app.backend.setConfig(cfg);
      await app.refresh();
      await _load();
      if (mounted) toast(context, 'Configuration saved. New matches use it.');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final fmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return GxScaffold(
      appBar: AppBar(title: const Text('ADMIN DASHBOARD'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Gx.gold))]),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Gx.bad))))
          : s == null
              ? const Center(child: CircularProgressIndicator(color: Gx.gold))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const SimBanner(),
                  const SectionHeader('Platform statistics'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.0,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      StatTile(label: 'Registered demo users', value: '${s.users}', icon: Icons.people),
                      StatTile(label: 'Total matches', value: '${s.matches}', icon: Icons.sports_esports),
                      StatTile(label: 'Completion rate', value: pct(s.completionRate), icon: Icons.check_circle_outline),
                      StatTile(label: 'Completed', value: '${s.completed}', icon: Icons.flag),
                      StatTile(label: 'Entry collections', value: inr(s.entries), icon: Icons.south_west),
                      StatTile(label: 'Payouts', value: inr(s.payouts), icon: Icons.north_east),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    glow: true,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PLATFORM GROSS MARGIN', style: Gx.label(color: Gx.goldLight)),
                          const SizedBox(height: 6),
                          Text(inr(s.margin), style: Gx.display(28, color: s.margin >= 0 ? Gx.goldLight : Gx.bad)),
                        ]),
                      ),
                      Text(pct(s.marginPct), style: Gx.display(26, color: Gx.gold)),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('Entry collections include the three AI demo entries per match (pool = 4 x entry). All figures are simulated.', style: Gx.label(size: 11)),
                  const SectionHeader('Match configuration'),
                  TextField(controller: _entry, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: fmt, decoration: const InputDecoration(labelText: 'Competitive entry (demo)', suffixText: 'coins')),
                  const SizedBox(height: 12),
                  TextField(controller: _tiers, decoration: const InputDecoration(labelText: 'Pro Bot entry tiers (comma separated)')),
                  const SizedBox(height: 12),
                  TextField(controller: _turn, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Turn timer (seconds, 5-120)')),
                  const SizedBox(height: 12),
                  Text('Payout multipliers (1st to 4th)', style: Gx.label(size: 12, color: Gx.text)),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: TextField(controller: _mult[i], onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: fmt, decoration: InputDecoration(labelText: ordinal(i + 1), suffixText: 'x')),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  PayoutBreakdown(cfg: _preview),
                  const SectionHeader('Bot configuration'),
                  Text('Competitive bot difficulty', style: Gx.label(size: 12, color: Gx.text)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [for (final d in kDifficulties) ButtonSegment(value: d, label: Text(difficultyLabel(d)))],
                    selected: {_botDiff},
                    onSelectionChanged: (v) => setState(() => _botDiff = v.first),
                    style: SegmentedButton.styleFrom(selectedBackgroundColor: Gx.gold.withOpacity(0.2), selectedForegroundColor: Gx.gold),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(controller: _names[i], maxLength: 12, decoration: InputDecoration(labelText: 'Bot ${i + 1} name - ${personaLabel(kPersonas[i])}', counterText: '')),
                    ),
                  Text('Bots play as: Rusher (aggressive), Guardian (safety first), Strategist (balanced).', style: Gx.label(size: 11.5)),
                  const SizedBox(height: 18),
                  GoldButton(label: 'SAVE CONFIGURATION', icon: Icons.save, loading: _saving, onPressed: _save),
                ]),
    );
  }
}
