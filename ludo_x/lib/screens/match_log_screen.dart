import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../engine/fair_dice.dart';
import '../services/backend.dart';
import '../services/models.dart';

/// Server-side match log with the dice commitment and, after the match,
/// the revealed seed that anyone can hash to verify the dice were not altered.
class MatchLogScreen extends StatefulWidget {
  final String matchId;
  const MatchLogScreen({super.key, required this.matchId});

  @override
  State<MatchLogScreen> createState() => _MatchLogScreenState();
}

class _MatchLogScreenState extends State<MatchLogScreen> {
  late Future<MatchLogBundle> _f;

  @override
  void initState() {
    super.initState();
    _f = app.backend.getMatchLog(widget.matchId);
  }

  IconData _icon(String t) {
    switch (t) {
      case 'roll':
        return Icons.casino;
      case 'move':
        return Icons.arrow_forward;
      case 'skip':
        return Icons.skip_next;
      case 'timeout':
        return Icons.timer_off;
      case 'violation':
      case 'flag':
        return Icons.gpp_maybe;
      case 'finish':
      case 'over':
        return Icons.emoji_events;
      default:
        return Icons.circle;
    }
  }

  Color _color(String t) => (t == 'violation' || t == 'flag') ? Gx.bad : (t == 'timeout' ? Gx.goldLight : Gx.muted);

  @override
  Widget build(BuildContext context) {
    return GxScaffold(
      appBar: AppBar(title: const Text('MATCH LOG')),
      body: FutureBuilder<MatchLogBundle>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Gx.gold));
          }
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: Gx.muted))));
          }
          final b = snap.data!;
          final verified = b.revealedSeed != null && FairDice.verifyCommitment(b.revealedSeed!, b.commitment);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                glow: verified,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(verified ? Icons.verified : Icons.lock_outline, color: verified ? Gx.good : Gx.gold, size: 20),
                    const SizedBox(width: 8),
                    Text(verified ? 'DICE VERIFIED' : 'DICE SEED SEALED', style: Gx.display(13, color: verified ? Gx.good : Gx.gold)),
                  ]),
                  const SizedBox(height: 10),
                  Text('Commitment (SHA-256 of the secret seed, published before roll #1)', style: Gx.label(size: 11)),
                  const SizedBox(height: 4),
                  SelectableText(b.commitment, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Gx.text)),
                  const SizedBox(height: 10),
                  Text('Seed', style: Gx.label(size: 11)),
                  const SizedBox(height: 4),
                  SelectableText(
                    b.revealedSeed ?? 'Hidden until the match ends, so rolls cannot be predicted.',
                    style: TextStyle(fontFamily: b.revealedSeed != null ? 'monospace' : null, fontSize: 11, color: b.revealedSeed != null ? Gx.text : Gx.muted),
                  ),
                  if (b.revealedSeed != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      verified ? 'sha256(seed) equals the commitment, and every roll is sha256(seed:n) - the dice cannot have been changed mid-match.' : 'Seed does not match the commitment!',
                      style: Gx.label(size: 11, color: verified ? Gx.good : Gx.bad),
                    ),
                  ],
                ]),
              ),
              const SectionHeader('Event log (hash chained)'),
              for (final e in b.entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Gx.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: e.type == 'violation' || e.type == 'flag' ? Gx.bad.withOpacity(0.6) : Gx.line),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_icon(e.type), size: 16, color: _color(e.type)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.text, style: const TextStyle(fontSize: 13, color: Gx.text, height: 1.3)),
                        const SizedBox(height: 2),
                        Text('#${e.n}  |  ${e.hash}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Gx.muted)),
                      ]),
                    ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
