import 'package:flutter/material.dart';

import '../core/payout.dart';
import '../core/theme.dart';

/// Transparent payout breakdown shown before a paid match starts and reused by
/// the standalone calculator.
class PayoutBreakdown extends StatelessWidget {
  final PayoutConfig cfg;
  final bool showMargin;
  const PayoutBreakdown({super.key, required this.cfg, this.showMargin = true});

  @override
  Widget build(BuildContext context) {
    const places = ['1st place', '2nd place', '3rd place', '4th place'];
    final pay = cfg.payouts;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _line('Entry per player', inr(cfg.entry)),
        _line('Players (you + 3 AI bots)', '4'),
        _line('Total demo pool', inr(cfg.pool), strong: true),
        const Divider(height: 20),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 22,
                child: Icon(i == 0 ? Icons.emoji_events : Icons.circle, size: i == 0 ? 17 : 7, color: i == 0 ? Gx.gold : Gx.muted),
              ),
              Expanded(child: Text(places[i], style: const TextStyle(color: Gx.text, fontWeight: FontWeight.w600))),
              Text('${cfg.multipliers[i].toStringAsFixed(cfg.multipliers[i] == cfg.multipliers[i].roundToDouble() ? 0 : 2)}x',
                  style: Gx.label(size: 12)),
              const SizedBox(width: 14),
              SizedBox(
                width: 78,
                child: Text(inr(pay[i]), textAlign: TextAlign.right, style: TextStyle(color: pay[i] > 0 ? Gx.goldLight : Gx.muted, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        const Divider(height: 20),
        _line('Total payout', inr(cfg.totalPayout), strong: true),
        if (showMargin) ...[
          _line('Platform demo margin', inr(cfg.margin), color: cfg.margin >= 0 ? Gx.text : Gx.bad),
          _line('Margin %', pct(cfg.marginPct), color: cfg.margin >= 0 ? Gx.text : Gx.bad),
        ],
        if (cfg.margin < 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.warning_amber, size: 16, color: Gx.bad),
              const SizedBox(width: 6),
              Expanded(child: Text('Payouts exceed the pool: this setup loses money.', style: Gx.label(size: 11.5, color: Gx.bad))),
            ]),
          ),
      ]),
    );
  }

  Widget _line(String l, String v, {bool strong = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(color: strong ? Gx.text : Gx.muted, fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
          Text(v, style: TextStyle(color: color ?? (strong ? Gx.gold : Gx.text), fontWeight: FontWeight.w800)),
        ]),
      );
}
