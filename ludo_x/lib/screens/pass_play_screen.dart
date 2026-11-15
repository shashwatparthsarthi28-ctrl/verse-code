import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/sound.dart';
import '../core/theme.dart';
import '../engine/ludo_engine.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/ludo_art.dart';

/// Pass N Play: 2-4 people share one phone. Uses the same rules engine as the
/// bot games, entirely on-device. No coins are charged or won.
class PassPlayScreen extends StatefulWidget {
  final int players;
  const PassPlayScreen({super.key, this.players = 4});

  @override
  State<PassPlayScreen> createState() => _PassPlayScreenState();
}

class _PassPlayScreenState extends State<PassPlayScreen> {
  final Random _rng = Random.secure();
  late final List<int> _active;
  late LudoState _st;
  int _dice = 0; // 0 = not rolled yet this turn
  int _lastDice = 0;
  int _face = 1;
  bool _rolling = false;
  bool _over = false;
  Set<int> _movable = <int>{};
  String _message = '';
  Timer? _anim;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    switch (widget.players) {
      case 2:
        _active = [0, 2];
        break;
      case 3:
        _active = [0, 1, 2];
        break;
      default:
        _active = [0, 1, 2, 3];
    }
    _st = LudoState.initial(_active.first);
    _message = '${_name(_st.turn)}: tap the dice to roll';
  }

  @override
  void dispose() {
    _anim?.cancel();
    _delay?.cancel();
    super.dispose();
  }

  String _name(int seat) => 'Player ${_active.indexOf(seat) + 1} (${Gx.seatName[seat]})';

  bool get _canRoll => !_over && !_rolling && _dice == 0;

  void _roll() {
    if (!_canRoll) return;
    Sfx.play('dice');
    setState(() => _rolling = true);
    var ticks = 0;
    _anim?.cancel();
    _anim = Timer.periodic(const Duration(milliseconds: 80), (t) {
      ticks++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (ticks < 8) {
        setState(() => _face = _rng.nextInt(6) + 1);
        return;
      }
      t.cancel();
      _settleRoll(_rng.nextInt(6) + 1);
    });
  }

  void _settleRoll(int value) {
    final seat = _st.turn;
    _st.sixes = value == 6 ? _st.sixes + 1 : 0;
    if (value == 6) Sfx.play('six');
    if (_st.sixes == 3) {
      setState(() {
        _rolling = false;
        _lastDice = value;
        _face = value;
        _message = '${_name(seat)} rolled three sixes - turn forfeited';
      });
      _delay = Timer(const Duration(milliseconds: 1200), _nextTurn);
      return;
    }
    final legal = _st.legalTokens(seat, value);
    setState(() {
      _rolling = false;
      _dice = value;
      _lastDice = value;
      _face = value;
      _movable = legal.toSet();
      _message = legal.isEmpty ? '${_name(seat)} rolled $value - no move' : '${_name(seat)} rolled $value - tap a token';
    });
    if (legal.isEmpty) {
      _delay = Timer(const Duration(milliseconds: 1000), _nextTurn);
    } else if (legal.length == 1) {
      _delay = Timer(const Duration(milliseconds: 450), () => _move(legal.first));
    }
  }

  void _onTokenTap(int token) {
    if (_over || _rolling || _dice == 0 || !_movable.contains(token)) return;
    _delay?.cancel();
    _move(token);
  }

  void _move(int token) {
    if (!mounted || _over || _dice == 0) return;
    final seat = _st.turn;
    final d = _dice;
    final out = _st.applyMove(seat, token, d);
    Sfx.play(out.captured.isNotEmpty ? 'capture' : (out.reachedHome ? 'home' : 'move'));
    if (_st.seatFinished(seat) && !_st.ranking.contains(seat)) _st.ranking.add(seat);
    final extra = (d == 6 || out.captured.isNotEmpty || out.reachedHome) && !_st.seatFinished(seat);

    final unfinished = _active.where((s) => !_st.seatFinished(s)).toList();
    if (unfinished.length <= 1) {
      for (final s in unfinished) {
        if (!_st.ranking.contains(s)) _st.ranking.add(s);
      }
      setState(() {
        _dice = 0;
        _movable = <int>{};
        _over = true;
        _message = '${_name(_st.ranking.first)} wins!';
      });
      Sfx.play('win');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
      return;
    }
    setState(() {
      _dice = 0;
      _movable = <int>{};
      _message = out.captured.isNotEmpty ? 'Captured! ${_name(seat)} rolls again' : (extra ? '${_name(seat)} rolls again' : '');
    });
    if (extra) {
      if (_message.isEmpty) setState(() => _message = '${_name(seat)} rolls again');
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (!mounted) return;
    var next = _st.turn;
    for (var i = 1; i <= Rules.seats; i++) {
      final c = (_st.turn + i) % Rules.seats;
      if (_active.contains(c) && !_st.seatFinished(c)) {
        next = c;
        break;
      }
    }
    setState(() {
      _st.turn = next;
      _st.sixes = 0;
      _dice = 0;
      _movable = <int>{};
      _message = '${_name(next)}: tap the dice to roll';
    });
  }

  Future<void> _confirmLeave() async {
    if (_over) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('This Pass N Play game will end. Nothing is lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay', style: TextStyle(color: Gx.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: Gx.bad, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  void _showResult() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('GAME OVER', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const CrownIcon(size: 56),
          const SizedBox(height: 10),
          for (var i = 0; i < _st.ranking.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 38, child: Text(ordinal(i + 1), style: TextStyle(fontWeight: FontWeight.w900, color: i == 0 ? Gx.goldLight : Gx.muted))),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Gx.seat[_st.ranking[i]], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
                const SizedBox(width: 8),
                Expanded(child: Text(_name(_st.ranking[i]), style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
          const SizedBox(height: 6),
          Text('Free game - no coins charged or won.', style: Gx.label(size: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Home', style: TextStyle(color: Gx.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => PassPlayScreen(players: widget.players)));
            },
            child: const Text('Play again', style: TextStyle(color: Gx.goldLight, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GxScaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              RoundIconButton(icon: Icons.close_rounded, onTap: _confirmLeave, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PASS N PLAY', style: Gx.display(14, color: Gx.goldLight)),
                  const SizedBox(height: 3),
                  Text('${widget.players} players on one phone - free game', style: Gx.label(size: 11)),
                ]),
              ),
            ]),
          ),
          _row(const [0, 1]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: BoardView(
                  tokens: _st.tokens,
                  movable: _movable,
                  activeSeat: _st.turn,
                  interactiveSeat: _st.turn,
                  onTokenTap: _onTokenTap,
                ),
              ),
            ),
          ),
          _row(const [3, 2]),
          _panel(),
        ]),
      ),
    );
  }

  Widget _row(List<int> seats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        for (var i = 0; i < seats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _active.contains(seats[i]) ? _card(seats[i]) : const SizedBox(height: 54)),
        ],
      ]),
    );
  }

  Widget _card(int seat) {
    final active = !_over && _st.turn == seat;
    final color = Gx.seat[seat];
    final home = _st.tokens[seat].where((p) => p == Rules.home).length;
    final rankIdx = _st.ranking.indexOf(seat);
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
          child: Text('${_active.indexOf(seat) + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Player ${_active.indexOf(seat) + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 3),
            Row(children: [
              Text(Gx.seatName[seat], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
              const Spacer(),
              if (rankIdx >= 0)
                Text(ordinal(rankIdx + 1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Gx.goldLight))
              else
                Text('$home/4', style: Gx.label(size: 11, color: Colors.white)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _panel() {
    final shown = _rolling ? _face : _lastDice;
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
        DiceView(value: shown, rolling: _rolling, enabled: _canRoll, color: Gx.seat[_st.turn], size: 72, onTap: _roll),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 11, height: 11, decoration: BoxDecoration(color: Gx.seat[_st.turn], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              const SizedBox(width: 8),
              Flexible(child: Text(_over ? 'GAME OVER' : _name(_st.turn).toUpperCase(), style: Gx.display(13, color: Gx.goldLight), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(_message, style: const TextStyle(color: Gx.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 6),
            Text('Roll a 6 to bring a token out. Sixes, captures and reaching home give another turn.', style: Gx.label(size: 10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
