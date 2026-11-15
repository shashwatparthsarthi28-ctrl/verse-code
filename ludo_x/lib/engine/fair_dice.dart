import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Commit-reveal dice. The server picks a secret seed, publishes
/// sha256(seed) before the first roll, derives every roll from
/// (seed, n) and reveals the seed after the match so anyone can audit it.
class FairDice {
  static String newSeed() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

  static String commitment(String seed) => sha256Hex(seed);

  /// Unbiased roll n (0-based) via rejection sampling: bytes >= 252 are skipped.
  static int roll(String seed, int n) {
    for (var c = 0;; c++) {
      final bytes = sha256.convert(utf8.encode('$seed:$n:$c')).bytes;
      for (final b in bytes) {
        if (b < 252) return (b % 6) + 1;
      }
    }
  }

  static bool verifyCommitment(String seed, String commitmentHex) => commitment(seed) == commitmentHex;
}
