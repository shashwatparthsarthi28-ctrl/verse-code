import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/dialogs.dart';
import '../widgets/ludo_art.dart';

/// Opens the Shop from anywhere (the green "+" on the coin pill uses this).
void openShop(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
}

/// Ludo X Shop. Coin packs add simulated demo coins through the backend ledger
/// (the same `demoDeposit` as before); the Ledger tab is the full wallet history.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const List<int> _packs = [500, 1000, 2500, 5000];
  static const Map<String, String> _tabs = {
    'coins': 'Coins',
    'ledger': 'Ledger',
    'dices': 'Dices',
    'themes': 'Themes',
    'stickers': 'Stickers',
    'pass': 'Pass',
  };

  List<WalletTxn> _tx = [];
  bool _loading = true;
  String _tab = 'coins';
  String _filter = 'all';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    _load();
    // lets "Pending (simulated)" withdrawals flip to completed while the screen is open
    _t = Timer.periodic(const Duration(seconds: 5), (_) => _r());
  }

  @override
  void dispose() {
    _t?.cancel();
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await app.refresh();
    try {
      final t = await app.backend.getTransactions();
      if (mounted) setState(() => _tx = t);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _grant(int amount) async {
    try {
      await app.backend.demoDeposit(amount.toDouble());
      Sfx.play('coin');
      await _load();
      if (mounted) toast(context, 'Added ${inr(amount.toDouble())} (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _deposit() async {
    final amt = await askAmount(context,
        title: 'Add demo coins', hint: 'Amount (demo)', confirm: 'ADD', quick: const [100, 500, 1000, 5000], max: app.config.maxDemoDeposit);
    if (amt == null) return;
    try {
      await app.backend.demoDeposit(amt);
      await _load();
      if (mounted) toast(context, 'Added ${inr(amt)} (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _withdraw() async {
    final amt = await askAmount(context, title: 'Request demo withdrawal', hint: 'Amount (demo)', confirm: 'REQUEST', quick: const [100, 500], max: app.balance);
    if (amt == null) return;
    try {
      await app.backend.requestWithdrawal(amt);
      await _load();
      if (mounted) toast(context, 'Simulated withdrawal requested. No real payout is made.');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  IconData _icon(String t) {
    switch (t) {
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdrawal':
        return Icons.arrow_circle_up_outlined;
      case 'entry':
        return Icons.sports_esports;
      case 'reward':
        return Icons.emoji_events;
      default:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          const GxTopBar(),
          const TitleRibbon('Shop'),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final e in _tabs.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: _tab == e.key ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD84A), Color(0xFFFF9E0B)]) : null,
                          color: _tab == e.key ? null : Gx.navy.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _tab == e.key ? Colors.white : Gx.line.withOpacity(0.6), width: 1.4),
                        ),
                        child: Text(e.value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _tab == e.key ? Gx.ink : Gx.muted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _content()),
        ]),
      ),
    );
  }

  Widget _content() {
    if (_tab == 'coins') return _coins();
    if (_tab == 'ledger') return _ledger();
    return _soon(_tabs[_tab] ?? '');
  }

  Widget _soon(String name) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Gx.navy.withOpacity(0.7), border: Border.all(color: Gx.line, width: 2)),
            child: const Icon(Icons.lock_rounded, size: 40, color: Gx.goldLight),
          ),
          const SizedBox(height: 16),
          Text(name.toUpperCase(), style: Gx.display(20)),
          const SizedBox(height: 6),
          Text('Coming soon', style: Gx.label(size: 14)),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ coins tab
  Widget _coins() {
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.98,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [for (final p in _packs) _pack(p)],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ChunkyButton(label: 'Custom amount', icon: Icons.add_circle_rounded, palette: Gx.green, height: 48, fontSize: 14, onTap: _deposit)),
            const SizedBox(width: 12),
            Expanded(child: ChunkyButton(label: 'Withdraw', icon: Icons.arrow_circle_up_rounded, palette: Gx.purple, height: 48, fontSize: 14, onTap: _withdraw)),
          ]),
          const SizedBox(height: 14),
          const SimBanner(),
        ],
      ),
    );
  }

  Widget _pack(int amount) {
    final stack = amount >= 5000 ? 4 : (amount >= 2500 ? 3 : (amount >= 1000 ? 2 : 1));
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2556D6), Color(0xFF153AB0)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Gx.line, width: 1.6),
        boxShadow: [BoxShadow(color: Gx.navy.withOpacity(0.9), offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Expanded(
          child: Center(
            child: SizedBox(
              height: 70,
              width: 90,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                for (var i = 0; i < stack; i++) Positioned(bottom: 2.0 + i * 12, child: CoinIcon(size: 52 - i * 2.0)),
              ]),
            ),
          ),
        ),
        Text('${coinNum(amount.toDouble())} Coins', style: Gx.display(15)),
        const SizedBox(height: 8),
        ChunkyButton(label: 'GET FREE', palette: Gx.yellow, textColor: Gx.ink, height: 38, fontSize: 13, onTap: () => _grant(amount)),
      ]),
    );
  }

  // ------------------------------------------------------------ ledger tab
  Widget _ledger() {
    const filters = {
      'all': 'All',
      'deposit': 'Deposits',
      'withdrawal': 'Withdrawals',
      'entry': 'Entries',
      'reward': 'Rewards',
    };
    final list = _filter == 'all' ? _tx : _tx.where((t) => t.type == _filter).toList();
    final deposits = _tx.where((t) => t.type == 'deposit').fold(0.0, (a, t) => a + t.amount);
    final entries = _tx.where((t) => t.type == 'entry').fold(0.0, (a, t) => a - t.amount);
    final rewards = _tx.where((t) => t.type == 'reward').fold(0.0, (a, t) => a + t.amount);
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Row(children: [
          Expanded(child: StatTile(label: 'Added', value: coinNum(deposits), icon: Icons.south_west)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(label: 'Entries', value: coinNum(entries), icon: Icons.confirmation_number_outlined)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(label: 'Rewards', value: coinNum(rewards), icon: Icons.emoji_events_outlined, valueColor: Gx.goldLight)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final e in filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value, style: TextStyle(fontWeight: FontWeight.w800, color: _filter == e.key ? Gx.ink : Gx.muted)),
                  selected: _filter == e.key,
                  selectedColor: Gx.gold,
                  backgroundColor: Gx.navy.withOpacity(0.7),
                  side: const BorderSide(color: Gx.line),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filter = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Gx.gold)))
        else if (list.isEmpty)
          AppCard(child: Text('No transactions here yet.', style: Gx.label(size: 13)))
        else
          for (final t in list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: (t.amount >= 0 ? Gx.good : Gx.bad).withOpacity(0.18)),
                    child: Icon(_icon(t.type), color: t.amount >= 0 ? Gx.good : Gx.bad, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.note, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${timeAgo(t.ts)}${t.displayStatus != null ? '  |  ${t.displayStatus}' : ''}', style: Gx.label(size: 11)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(inr(t.amount, sign: true), style: TextStyle(fontWeight: FontWeight.w900, color: t.amount >= 0 ? Gx.good : Gx.bad)),
                    Text('Bal ${inr(t.balanceAfter)}', style: Gx.label(size: 10.5)),
                  ]),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        const SimBanner(compact: true),
      ]),
    );
  }
}
