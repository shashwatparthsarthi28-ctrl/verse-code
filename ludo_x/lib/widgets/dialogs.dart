import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Asks for a demo amount. Returns null if cancelled.
Future<double?> askAmount(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirm,
  List<int> quick = const [],
  double? max,
}) {
  final c = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final v = double.tryParse(c.text.trim());
      final err = (c.text.isNotEmpty && (v == null || v <= 0))
          ? 'Enter a positive amount'
          : (v != null && max != null && v > max)
              ? 'Maximum is ${inr(max)}'
              : null;
      return AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SimBanner(compact: true),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => set(() {}),
            decoration: InputDecoration(labelText: hint, suffixText: 'coins', errorText: err),
          ),
          if (quick.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in quick)
                ActionChip(
                  label: Text(inr(q.toDouble()), style: const TextStyle(fontWeight: FontWeight.w800, color: Gx.gold)),
                  backgroundColor: Gx.card,
                  side: const BorderSide(color: Gx.line),
                  onPressed: () => set(() => c.text = q.toString()),
                ),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
          TextButton(
            onPressed: (v != null && v > 0 && err == null) ? () => Navigator.pop(ctx, v) : null,
            child: Text(confirm, style: const TextStyle(color: Gx.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    }),
  );
}
