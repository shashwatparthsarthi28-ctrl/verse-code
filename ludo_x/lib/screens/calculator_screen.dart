import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/payout.dart';
import '../core/theme.dart';
import '../widgets/payout_breakdown.dart';

/// Dynamic payout calculator: every change recomputes pool, payouts and margin instantly.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _entry = TextEditingController(text: '100');
  final List<TextEditingController> _mult = [
    for (final m in PayoutConfig.defaultMultipliers) TextEditingController(text: m.toString()),
  ];

  @override
  void dispose() {
    _entry.dispose();
    for (final c in _mult) c.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  PayoutConfig get _cfg => PayoutConfig(entry: _num(_entry), multipliers: [for (final c in _mult) _num(c)]);

  void _reset() => setState(() {
        _entry.text = '100';
        for (var i = 0; i < 4; i++) _mult[i].text = PayoutConfig.defaultMultipliers[i].toString();
      });

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    const labels = ['1st place', '2nd place', '3rd place', '4th place'];
    final fmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return GxScaffold(
      appBar: AppBar(title: const Text('PAYOUT CALCULATOR'), actions: [
        TextButton(onPressed: _reset, child: const Text('Reset', style: TextStyle(color: Gx.gold))),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SimBanner(compact: true),
        const SizedBox(height: 14),
        TextField(
          controller: _entry,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: fmt,
          decoration: const InputDecoration(labelText: 'Entry fee per player (demo)', suffixText: 'coins'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final q in const [50, 100, 200])
            ActionChip(
              label: Text('$q', style: const TextStyle(color: Gx.gold, fontWeight: FontWeight.w800)),
              backgroundColor: Gx.card,
              side: const BorderSide(color: Gx.line),
              onPressed: () => setState(() => _entry.text = '$q'),
            ),
        ]),
        const SectionHeader('Multipliers'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.9,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < 4; i++)
              TextField(
                controller: _mult[i],
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: fmt,
                decoration: InputDecoration(labelText: labels[i], suffixText: 'x'),
              ),
          ],
        ),
        const SectionHeader('Result'),
        PayoutBreakdown(cfg: cfg),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatTile(label: 'Total payout', value: inr(cfg.totalPayout))),
          const SizedBox(width: 10),
          Expanded(child: StatTile(label: 'Gross margin', value: '${inr(cfg.margin)} (${pct(cfg.marginPct)})', valueColor: cfg.margin >= 0 ? Gx.goldLight : Gx.bad)),
        ]),
        const SizedBox(height: 12),
        Text('Pool = entry x 4 players (you + 3 AI bots). Payout = entry x multiplier. Margin = pool - total payout.', style: Gx.label(size: 11.5)),
      ]),
    );
  }
}
