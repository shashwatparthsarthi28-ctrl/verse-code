import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/payout.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../engine/bot_ai.dart';
import '../engine/fair_dice.dart';
import '../services/backend.dart';
import '../services/models.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/ludo_art.dart';
import '../widgets/progress_widgets.dart';
import 'match_log_screen.dart';

String modeTitle(String mode) {
  switch (mode) {
    case 'practice':
      return 'Vs Computer';
    case 'competitive':
      return 'Competitive';
    default:
      return 'Pro Challenge';
  }
}

/// Drives one match. It only ever sends intents to the backend and animates the
/// authoritative snapshots it gets back, so the client cannot influence dice,
/// balances or outcomes.
class GameController extends ChangeNotifier {
  final GameBackend backend;
  final String mode;
  final double entry;
  final List<String>? difficulties;

  GameController({required this.backend, required this.mode, this.entry = 0, this.difficulties});

  MatchSnapshot? snap;
  int startXp = 0;
  List<List<int>> display = List.generate(4, (_) => List<int>.filled(4, -1));
  int lastDice = 0;
  int lastRollSeat = 0;
  int faceShown = 0;
  bool rolling = false;
  bool busy = false;
  bool resumed = false;
  bool resultReady = false;
  String message = 'Setting up match...';
  String? fatal;
  int secondsLeft = 0;

  bool _disposed = false;
  bool _driving = false;
  bool _input = false;
  int _failures = 0;
  int _clockOffset = 0;
  int _timeoutCooldownUntil = 0;
  Timer? _ticker;
  final Random _rng = Random();

  bool get canRoll {
    final s = snap;
    return s != null && s.humanTurn && s.dice == null && !busy && !rolling && !_driving && !_input && !s.over;
  }

  Set<int> get movable {
    final s = snap;
    if (s == null || !s.humanTurn || s.dice == null || busy || rolling || _driving) return <int>{};
    return s.legal.toSet();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  String _turnMessage() {
    final s = snap;
    if (s == null) return '';
    if (s.over) return 'Match over';
    final name = s.seats[s.turn].displayName;
    if (!s.seats[s.turn].isBot) {
      return s.dice == null ? 'Your turn - tap the dice' : 'Choose a token to move';
    }
    return '$name is playing...';
  }

  void _adopt(MatchSnapshot s) {
    snap = s;
    display = s.tokens.map((r) => List<int>.from(r)).toList();
    _clockOffset = s.serverNowMs - DateTime.now().millisecondsSinceEpoch;
    message = _turnMessage();
  }

  Future<void> start() async {
    startXp = app.profile?.xp ?? 0;
    try {
      final s = await backend.createMatch(mode: mode, entry: entry, difficulties: difficulties);
      resumed = s.resumed;
      _adopt(s);
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      _notify();
      unawaited(app.refresh());
      unawaited(_drive());
    } catch (e) {
      fatal = e.toString();
      _notify();
    }
  }

  // ------------------------------------------------------------ animations
  Future<void> _animateRoll(MatchEvent ev, MatchSnapshot s) async {
    final name = s.seats[ev.seat].displayName;
    rolling = true;
    lastRollSeat = ev.seat;
    message = '$name rolls...';
    Sfx.play('dice');
    final end = DateTime.now().millisecondsSinceEpoch + 560;
    while (DateTime.now().millisecondsSinceEpoch < end && !_disposed) {
      faceShown = 1 + _rng.nextInt(6);
      _notify();
      await _wait(70);
    }
    rolling = false;
    faceShown = ev.value;
    lastDice = ev.value;
    if (ev.value == 6) Sfx.play('six');
    if (ev.skipped != null) {
      message = ev.skipped == 'three_sixes' ? 'Three sixes in a row - turn forfeited' : '$name rolled ${ev.value} - no legal move';
      _notify();
      await _wait(950);
    } else {
      message = '$name rolled ${ev.value}';
      _notify();
      await _wait(320);
    }
  }

  Future<void> _animateMove(MatchEvent ev, MatchSnapshot s) async {
    final seat = ev.seat;
    final t = ev.token;
    final name = s.seats[seat].displayName;
    if (ev.from == -1) {
      display[seat][t] = 0;
      Sfx.play('move');
      _notify();
      await _wait(240);
    } else {
      for (var p = ev.from + 1; p <= ev.to && !_disposed; p++) {
        display[seat][t] = p;
        Sfx.play('move');
        _notify();
        await _wait(115);
      }
    }
    if (ev.captured.isNotEmpty) {
      Sfx.play('capture');
      Sfx.haptic(heavy: true);
      for (final c in ev.captured) {
        display[c[0]][c[1]] = -1;
      }
      message = '$name captured ${ev.captured.length == 1 ? 'a token' : '${ev.captured.length} tokens'}!';
      _notify();
      await _wait(480);
    }
    if (ev.home) {
      Sfx.play('home');
      message = '$name brought a token home';
      _notify();
      await _wait(380);
    }
  }

  Future<void> _apply(MatchSnapshot next) async {
    final ev = next.event;
    if (ev != null && ev.type == 'roll') {
      await _animateRoll(ev, next);
    } else if (ev != null && ev.type == 'move') {
      await _animateMove(ev, next);
    }
    _adopt(next);
    _failures = 0;
    _notify();
  }

  // ------------------------------------------------------------ turn driver
  Future<void> _drive() async {
    if (_driving) return;
    _driving = true;
    _notify();
    try {
      while (!_disposed) {
        final s = snap;
        if (s == null || s.over) break;
        if (!s.seats[s.turn].isBot) {
          if (s.dice != null && s.legal.length == 1) {
            // only one possible move: play it automatically
            await _wait(420);
            if (_disposed || snap != s) continue;
            busy = true;
            _notify();
            final next = await backend.moveToken(s.id, s.legal.first, s.seq);
            await _apply(next);
            busy = false;
            continue;
          }
          break; // waiting for the human
        }
        await _wait(max(350, app.config.botThinkMs));
        if (_disposed || snap != s) continue;
        busy = true;
        _notify();
        final next = await backend.botStep(s.id, s.seq);
        await _apply(next);
        busy = false;
      }
    } catch (e) {
      busy = false;
      await _recover(e);
    } finally {
      _driving = false;
      _notify();
    }
    final cur = snap;
    if (cur != null && cur.over && !resultReady) {
      resultReady = true;
      _notify();
      unawaited(app.refresh());
    } else if (!_disposed && cur != null && !cur.over && fatal == null) {
      final botTurn = cur.seats[cur.turn].isBot;
      final autoMove = cur.humanTurn && cur.dice != null && cur.legal.length == 1;
      if (botTurn || autoMove) unawaited(_drive());
    }
  }

  Future<void> _recover(Object e) async {
    _failures++;
    final id = snap?.id;
    if (_failures > 3 || id == null) {
      fatal = e.toString();
      _notify();
      return;
    }
    message = 'Re-syncing with the server...';
    _notify();
    try {
      final fresh = await backend.getMatch(id);
      _adopt(fresh);
    } catch (e2) {
      fatal = e2.toString();
    }
    _notify();
  }

  // ------------------------------------------------------------ human input
  Future<void> onDiceTap() async {
    final s = snap;
    if (s == null || !canRoll) return;
    _input = true;
    busy = true;
    _notify();
    try {
      final next = await backend.rollDice(s.id, s.seq);
      await _apply(next);
    } catch (e) {
      await _recover(e);
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  Future<void> onTokenTap(int token) async {
    final s = snap;
    if (s == null || _input || !movable.contains(token)) return;
    _input = true;
    busy = true;
    _notify();
    try {
      final next = await backend.moveToken(s.id, token, s.seq);
      await _apply(next);
    } catch (e) {
      await _recover(e);
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  // ------------------------------------------------------------ turn timer
  void _tick() {
    final s = snap;
    if (s == null || s.over || _disposed) return;
    final nowSrv = DateTime.now().millisecondsSinceEpoch + _clockOffset;
    final leftMs = s.deadlineMs - nowSrv;
    final left = max(0, (leftMs / 1000).ceil());
    if (left != secondsLeft) {
      secondsLeft = left;
      if (s.humanTurn && left > 0 && left <= 5 && !busy) Sfx.play('tick');
      _notify();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (s.humanTurn && leftMs <= -300 && !_input && !_driving && !busy && now > _timeoutCooldownUntil) {
      _timeout(s);
    }
  }

  Future<void> _timeout(MatchSnapshot s) async {
    _input = true;
    busy = true;
    message = "Time's up - auto play";
    _notify();
    try {
      final next = await backend.timeoutTurn(s.id, s.seq);
      await _apply(next);
    } catch (_) {
      _timeoutCooldownUntil = DateTime.now().millisecondsSinceEpoch + 1500;
      try {
        _adopt(await backend.getMatch(s.id));
      } catch (_) {}
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  Future<void> retry() async {
    final id = snap?.id;
    fatal = null;
    _failures = 0;
    if (id == null) {
      await start();
      return;
    }
    try {
      _adopt(await backend.getMatch(id));
    } catch (e) {
      fatal = e.toString();
    }
    _notify();
    unawaited(_drive());
  }

  Future<void> leave() async {
    final s = snap;
    if (s != null && !s.over) {
      try {
        await backend.abandonMatch(s.id);
      } catch (_) {}
    }
    unawaited(app.refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}

// =====================================================================================

class GameScreen extends StatefulWidget {
  final String mode;
  final double entry;
  final List<String>? difficulties;
  const GameScreen({super.key, required this.mode, this.entry = 0, this.difficulties});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController ctrl;
  bool _resultShown = false;
  bool _resumedToast = false;

  @override
  void initState() {
    super.initState();
    ctrl = GameController(backend: app.backend, mode: widget.mode, entry: widget.entry, difficulties: widget.difficulties);
    ctrl.addListener(_onChange);
    ctrl.start();
  }

  void _onChange() {
    if (!mounted) return;
    if (ctrl.resumed && !_resumedToast && ctrl.snap != null) {
      _resumedToast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, 'Resumed your unfinished match - no second entry was charged.');
      });
    }
    if (ctrl.resultReady && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
    }
  }

  @override
  void dispose() {
    ctrl.removeListener(_onChange);
    ctrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final paid = widget.entry > 0 || widget.mode == 'competitive';
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave match?'),
        content: Text(paid
            ? 'Leaving counts as a loss: your simulated entry is forfeited and you finish 4th with no reward.'
            : 'This free game will end. Nothing is lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Leave', style: TextStyle(color: Gx.bad)),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _showResult() async {
    final s = ctrl.snap!;
    if (s.humanRank == 1) Sfx.play('win');
    final gain = Progress.xpForMatch(rank: s.humanRank, completed: s.status == 'completed');
    if (Progress.levelOf(ctrl.startXp + gain) > Progress.levelOf(ctrl.startXp)) {
      Future<void>.delayed(const Duration(milliseconds: 1100), () => Sfx.play('levelup'));
    }
    final again = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _ResultDialog(snap: s, backend: app.backend, startXp: ctrl.startXp),
    );
    if (!mounted) return;
    if (again == 'again') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(mode: widget.mode, entry: widget.entry, difficulties: widget.difficulties),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final s = ctrl.snap;
        return PopScope(
          canPop: s == null || s.over || ctrl.fatal != null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave()) {
              await ctrl.leave();
              if (mounted) Navigator.of(context).pop();
            }
          },
          child: GxScaffold(
            body: SafeArea(child: _body(s)),
          ),
        );
      },
    );
  }

  Widget _body(MatchSnapshot? s) {
    if (ctrl.fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, color: Gx.bad, size: 56),
            const SizedBox(height: 16),
            Text(ctrl.fatal!, textAlign: TextAlign.center, style: const TextStyle(color: Gx.text)),
            const SizedBox(height: 22),
            GoldButton(label: 'Try again', icon: Icons.refresh, onPressed: ctrl.retry),
            const SizedBox(height: 10),
            GoldButton(label: 'Back', outlined: true, onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      );
    }
    if (s == null) {
      return const Center(child: CircularProgressIndicator(color: Gx.gold));
    }
    return Column(children: [
      _TopBar(ctrl: ctrl, snap: s, onClose: () async {
        if (s.over || await _confirmLeave()) {
          await ctrl.leave();
          if (mounted) Navigator.of(context).pop();
        }
      }),
      _PlayerRow(snap: s, seats: const [0, 1]),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: BoardView(
              tokens: ctrl.display,
              movable: ctrl.movable,
              activeSeat: s.turn,
              onTokenTap: ctrl.onTokenTap,
            ),
          ),
        ),
      ),
      _PlayerRow(snap: s, seats: const [3, 2]),
      _ControlPanel(ctrl: ctrl, snap: s),
    ]);
  }
}

// ---------------------------------------------------------------- pieces

class _TopBar extends StatelessWidget {
  final GameController ctrl;
  final MatchSnapshot snap;
  final VoidCallback onClose;
  const _TopBar({required this.ctrl, required this.snap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final humanTurn = snap.humanTurn;
    final total = max(1, snap.turnMs ~/ 1000);
    final frac = (ctrl.secondsLeft / total).clamp(0.0, 1.0);
    final urgent = humanTurn && ctrl.secondsLeft <= 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        RoundIconButton(icon: Icons.close_rounded, onTap: onClose, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(modeTitle(snap.mode).toUpperCase(), style: Gx.display(14, color: Gx.goldLight)),
            const SizedBox(height: 3),
            Text(
              snap.entry > 0
                  ? 'Entry ${inr(snap.entry)}  |  Pool ${inr(snap.entry * 4)}  |  1st ${inr(PayoutConfig(entry: snap.entry, multipliers: snap.multipliers).payouts[0])}'
                  : 'Free game - no coins charged or won',
              style: Gx.label(size: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        RoundIconButton(
          icon: Icons.receipt_long_rounded,
          size: 40,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MatchLogScreen(matchId: snap.id))),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Gx.navy.withOpacity(0.8)),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: humanTurn ? frac : 0,
                strokeWidth: 4,
                backgroundColor: Gx.line.withOpacity(0.5),
                color: urgent ? Gx.bad : Gx.gold,
              ),
            ),
            Text(humanTurn ? '${ctrl.secondsLeft}' : '-', style: TextStyle(fontWeight: FontWeight.w900, color: urgent ? Gx.bad : Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

/// Two player cards side by side (top row: seats 0 and 1, bottom row: seats 3 and 2).
class _PlayerRow extends StatelessWidget {
  final MatchSnapshot snap;
  final List<int> seats;
  const _PlayerRow({required this.snap, required this.seats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        for (var i = 0; i < seats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _SeatChip(seat: snap.seats[seats[i]], snap: snap)),
        ],
      ]),
    );
  }
}

class _SeatChip extends StatelessWidget {
  final SeatInfo seat;
  final MatchSnapshot snap;
  const _SeatChip({required this.seat, required this.snap});

  @override
  Widget build(BuildContext context) {
    final active = !snap.over && snap.turn == seat.seat;
    final home = snap.tokens[seat.seat].where((p) => p == 56).length;
    final color = Gx.seat[seat.seat];
    final rankIdx = snap.state.ranking.indexOf(seat.seat);
    final me = !seat.isBot;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: Gx.navy.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? Gx.goldLight : color, width: active ? 2.6 : 1.8),
        boxShadow: active ? [BoxShadow(color: Gx.gold.withOpacity(0.5), blurRadius: 14)] : null,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.3), border: Border.all(color: color, width: 2.5)),
          child: me
              ? AvatarView(index: app.profile?.avatar ?? 0, size: 34, ring: false)
              : const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(seat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 3),
            Row(children: [
              me ? const MiniTag('YOU') : const MiniTag('AI BOT', color: Gx.muted),
              const Spacer(),
              if (rankIdx >= 0)
                Text(ordinal(rankIdx + 1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Gx.goldLight))
              else
                Text('$home/4', style: Gx.label(size: 11, color: Colors.white)),
            ]),
            if (seat.isBot)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${difficultyLabel(seat.difficulty ?? 'medium')} - ${personaLabel(seat.persona ?? 'strategist')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: Gx.muted, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final GameController ctrl;
  final MatchSnapshot snap;
  const _ControlPanel({required this.ctrl, required this.snap});

  @override
  Widget build(BuildContext context) {
    final turnSeat = snap.seats[snap.turn];
    final shown = ctrl.rolling ? ctrl.faceShown : ctrl.lastDice;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14389E), Color(0xFF0A1F6B)]),
        border: Border.all(color: Gx.line, width: 1.6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 4), blurRadius: 6)],
      ),
      child: Row(children: [
        DiceView(
          value: shown,
          rolling: ctrl.rolling,
          enabled: ctrl.canRoll,
          color: Gx.seat[ctrl.lastRollSeat],
          size: 72,
          onTap: ctrl.onDiceTap,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 11, height: 11, decoration: BoxDecoration(color: Gx.seat[snap.turn], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  snap.over ? 'MATCH OVER' : '${Gx.seatName[snap.turn].toUpperCase()}  ${turnSeat.isBot ? '(AI BOT)' : '(YOU)'}',
                  style: Gx.display(13, color: Gx.goldLight),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(ctrl.message, style: const TextStyle(color: Gx.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 6),
            Text(
              ctrl.canRoll ? 'Dice are rolled by the server - tap to roll' : 'Roll a 6 to bring a token out. Sixes, captures and reaching home give another turn.',
              style: Gx.label(size: 10.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- result

class _ResultDialog extends StatelessWidget {
  final MatchSnapshot snap;
  final GameBackend backend;
  final int startXp;
  const _ResultDialog({required this.snap, required this.backend, required this.startXp});

  @override
  Widget build(BuildContext context) {
    final rank = snap.humanRank;
    final abandoned = snap.status == 'abandoned';
    final paid = snap.entry > 0;
    final table = PayoutConfig(entry: snap.entry, multipliers: snap.multipliers);
    final payout = abandoned ? 0.0 : (paid ? table.payoutForRank(rank) : 0.0);
    final net = payout - snap.entry;
    final fair = snap.revealedSeed != null && FairDice.verifyCommitment(snap.revealedSeed!, snap.commitment);
    final headline = abandoned ? 'MATCH ABANDONED' : (rank == 1 ? 'VICTORY!' : '${ordinal(rank).toUpperCase()} PLACE');

    final gain = Progress.xpForMatch(rank: rank, completed: !abandoned && snap.status == 'completed');
    final levelUp = Progress.levelOf(startXp + gain) > Progress.levelOf(startXp);
    return Dialog(
      child: Stack(children: [
        if (rank == 1 && !abandoned) const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
        SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(rank == 1 && !abandoned ? Icons.emoji_events : Icons.flag, size: 54, color: Gx.gold),
          const SizedBox(height: 8),
          Text(headline, style: Gx.display(24, color: Gx.gold)),
          const SizedBox(height: 14),
          for (var i = 0; i < snap.finalOrder.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: snap.finalOrder[i] == 0 ? Gx.gold.withOpacity(0.12) : Gx.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: snap.finalOrder[i] == 0 ? Gx.gold : Gx.line),
              ),
              child: Row(children: [
                SizedBox(width: 34, child: Text(ordinal(i + 1), style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.gold))),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Gx.seat[snap.finalOrder[i]], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(snap.seats[snap.finalOrder[i]].displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
                snap.seats[snap.finalOrder[i]].isBot ? const MiniTag('AI', color: Gx.muted) : const MiniTag('YOU'),
                if (paid) ...[
                  const SizedBox(width: 10),
                  Text(inr(table.payouts[i]), style: const TextStyle(color: Gx.goldLight, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          const SizedBox(height: 10),
          if (gain > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Gx.gold.withOpacity(0.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Gx.gold)),
              child: Row(children: [
                const Icon(Icons.bolt, color: Gx.gold),
                const SizedBox(width: 8),
                Text('+$gain XP', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.goldLight)),
                const Spacer(),
                if (levelUp) Text('LEVEL UP! Lv ${Progress.levelOf(startXp + gain)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.good)),
              ]),
            ),
          if (paid)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _row('Entry', inr(-snap.entry), Gx.bad),
                _row('Simulated reward', inr(payout, sign: true), payout > 0 ? Gx.good : Gx.muted),
                const Divider(height: 18),
                _row('Net result', inr(net, sign: true), net >= 0 ? Gx.good : Gx.bad, bold: true),
              ]),
            )
          else
            const Text('Free game - no coins charged or won.', style: TextStyle(color: Gx.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(fair ? Icons.verified : Icons.help_outline, size: 16, color: fair ? Gx.good : Gx.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fair ? 'Dice verified: revealed seed matches the commitment published before the match.' : 'Fairness data unavailable.',
                style: Gx.label(size: 11, color: fair ? Gx.good : Gx.muted),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          GoldButton(label: 'Play again', icon: Icons.replay, onPressed: () => Navigator.pop(context, 'again')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: GoldButton(
                label: 'Match log',
                outlined: true,
                compact: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchLogScreen(matchId: snap.id))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: GoldButton(label: 'Home', outlined: true, compact: true, onPressed: () => Navigator.pop(context, 'home'))),
          ]),
        ]),
      ),
      ]),
    );
  }

  Widget _row(String l, String v, Color c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(color: Gx.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: bold ? 17 : 14)),
        ]),
      );
}
