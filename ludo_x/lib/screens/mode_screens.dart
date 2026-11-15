import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/payout.dart';
import '../core/theme.dart';
import '../engine/bot_ai.dart';
import '../widgets/ludo_art.dart';
import '../widgets/payout_breakdown.dart';
import 'game_screen.dart';
import 'wallet_screen.dart';

Widget _botRoster(List<String> names, List<String> diffs) {
  return AppCard(
    child: Column(children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Gx.seat[i + 1], shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(i < names.length ? names[i] : 'Bot${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
            const MiniTag('AI BOT', color: Gx.muted),
            const SizedBox(width: 8),
            Text('${difficultyLabel(diffs[i])} - ${personaLabel(kPersonas[i])}', style: Gx.label(size: 11.5)),
          ]),
        ),
    ]),
  );
}

/// MODE 2: Competitive Demo. Shows the transparent payout breakdown first.
class CompetitiveScreen extends StatelessWidget {
  const CompetitiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = app.config;
    final pc = PayoutConfig(entry: cfg.competitiveEntry, multipliers: cfg.multipliers);
    final enough = app.balance >= cfg.competitiveEntry;
    return GxScaffold(
      body: SafeArea(child: Column(children: [
        GxTopBar(onAddCoins: () => openShop(context)),
        const TitleRibbon('Competitive'),
        const SizedBox(height: 6),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        const SimBanner(),
        const SectionHeader('Payout breakdown'),
        PayoutBreakdown(cfg: pc),
        const SectionHeader('Your opponents'),
        _botRoster(cfg.botNames, List.filled(3, cfg.competitiveBotDifficulty)),
        const SizedBox(height: 8),
        Text('All three opponents are AI bots, clearly labelled in the game. Their entries are demo entries that fill the pool.', style: Gx.label(size: 11.5)),
        const SectionHeader('Your wallet'),
        AppCard(
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: Gx.gold),
            const SizedBox(width: 12),
            Expanded(child: Text('Balance ${inr(app.balance)}', style: const TextStyle(fontWeight: FontWeight.w800))),
            if (!enough) const MiniTag('INSUFFICIENT', color: Gx.bad),
          ]),
        ),
        const SizedBox(height: 18),
        GoldButton(
          label: enough ? 'PAY ${inr(cfg.competitiveEntry)} ENTRY & PLAY' : 'NEED MORE COINS - OPEN SHOP',
          icon: Icons.play_arrow,
          onPressed: enough
              ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen(mode: 'competitive')))
              : () => openShop(context),
        ),
        if (!enough)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Tap the green + next to your coins to add simulated coins in the Shop.', style: Gx.label(size: 12), textAlign: TextAlign.center),
          ),
      ])),
      ])),
    );
  }
}

/// MODE 3: Pro Bot Challenge with adjustable bot difficulty and entry tiers.
class ProBotScreen extends StatefulWidget {
  const ProBotScreen({super.key});

  @override
  State<ProBotScreen> createState() => _ProBotScreenState();
}

class _ProBotScreenState extends State<ProBotScreen> {
  late double _tier = app.config.proTiers.length > 1 ? app.config.proTiers[1] : app.config.proTiers.first;
  final List<String> _diff = ['medium', 'medium', 'medium'];
  bool _same = true;

  void _setAll(String d) => setState(() {
        for (var i = 0; i < 3; i++) _diff[i] = d;
      });

  @override
  Widget build(BuildContext context) {
    final cfg = app.config;
    final pc = PayoutConfig(entry: _tier, multipliers: cfg.multipliers);
    final enough = app.balance >= _tier;
    return GxScaffold(
      body: SafeArea(child: Column(children: [
        GxTopBar(onAddCoins: () => openShop(context)),
        const TitleRibbon('Pro Challenge'),
        const SizedBox(height: 6),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        const SimBanner(),
        const SectionHeader('Entry tier'),
        Row(children: [
          for (final t in cfg.proTiers)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _tier = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _tier == t ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD84A), Color(0xFFFF9E0B)]) : null,
                      color: _tier == t ? null : Gx.navy.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _tier == t ? Gx.goldLight : Gx.line),
                    ),
                    child: Center(child: Text(inr(t), style: Gx.display(16, color: _tier == t ? Gx.ink : Gx.text))),
                  ),
                ),
              ),
            ),
        ]),
        const SectionHeader('Bot difficulty'),
        Row(children: [
          Expanded(child: Text('Same difficulty for all bots', style: Gx.label(size: 13, color: Gx.text))),
          Switch(value: _same, activeColor: Gx.gold, onChanged: (v) => setState(() {
                _same = v;
                if (v) _setAll(_diff[0]);
              })),
        ]),
        const SizedBox(height: 4),
        if (_same)
          _DiffPicker(value: _diff[0], onChanged: _setAll)
        else
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(bottom: 6, left: 2), child: Text('${cfg.botNames[i]} (${personaLabel(kPersonas[i])})', style: Gx.label(size: 12, color: Gx.text))),
                _DiffPicker(value: _diff[i], onChanged: (d) => setState(() => _diff[i] = d)),
              ]),
            ),
        const SizedBox(height: 4),
        Text(
          'Easy: random legal moves.  Medium: strategy with occasional slips.  Hard: strategy plus risk analysis (avoids squares opponents can hit).',
          style: Gx.label(size: 11.5),
        ),
        const SectionHeader('Your opponents'),
        _botRoster(cfg.botNames, _diff),
        const SectionHeader('Simulated payouts'),
        PayoutBreakdown(cfg: pc),
        const SizedBox(height: 18),
        GoldButton(
          label: enough ? 'PAY ${inr(_tier)} ENTRY & PLAY' : 'NOT ENOUGH COINS - OPEN SHOP',
          icon: Icons.play_arrow,
          onPressed: enough
              ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(mode: 'pro', entry: _tier, difficulties: List.of(_diff))))
              : () => openShop(context),
        ),
      ])),
      ])),
    );
  }
}

class _DiffPicker extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _DiffPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const colors = {'easy': Gx.good, 'medium': Gx.goldLight, 'hard': Gx.bad};
    return Row(children: [
      for (final d in kDifficulties)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == d ? colors[d]!.withOpacity(0.22) : Gx.navy.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: value == d ? colors[d]! : Gx.line, width: value == d ? 1.8 : 1),
                ),
                child: Center(child: Text(difficultyLabel(d).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6, fontSize: 12.5, color: value == d ? colors[d] : Gx.muted))),
              ),
            ),
          ),
        ),
    ]);
  }
}
