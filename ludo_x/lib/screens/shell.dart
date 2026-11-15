import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'home_screen.dart';

/// Root of the signed-in app: the Ludo X main menu. Every other screen is
/// pushed on top of it with a round back button.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Timer? _break;

  @override
  void initState() {
    super.initState();
    // Healthy-play reminder: a gentle nudge every 45 minutes.
    _break = Timer.periodic(const Duration(minutes: 45), (_) {
      if (mounted) toast(context, "You've been playing for a while. Take a short break!");
    });
  }

  @override
  void dispose() {
    _break?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const GxScaffold(body: SafeArea(child: HomeScreen()));
  }
}
