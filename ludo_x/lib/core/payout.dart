double r2(double x) => (x * 100).roundToDouble() / 100;

/// Dynamic payout calculator. Four players, every seat pays [entry] into the pool
/// (three seats are AI demo entries) and payouts are entry x multiplier.
/// Defaults: 1.6x / 1.2x / 0.7x / 0x => with a 100 entry: 160 / 120 / 70 / 0.
class PayoutConfig {
  final double entry;
  final List<double> multipliers; // 4 values, rank 1..4

  const PayoutConfig({required this.entry, this.multipliers = const [1.6, 1.2, 0.7, 0.0]});

  static const int players = 4;
  static const List<double> defaultMultipliers = [1.6, 1.2, 0.7, 0.0];

  double get pool => r2(entry * players);
  List<double> get payouts => multipliers.map((m) => r2(entry * m)).toList();
  double get totalPayout => r2(payouts.fold(0.0, (a, b) => a + b));
  double get margin => r2(pool - totalPayout);
  double get marginPct => pool == 0 ? 0 : r2(margin / pool * 100);

  /// A configuration is sustainable only if the pool covers every payout.
  bool get isValid => entry > 0 && multipliers.length == 4 && multipliers.every((m) => m >= 0) && margin >= 0;

  double payoutForRank(int rank) => (rank >= 1 && rank <= 4) ? payouts[rank - 1] : 0;

  PayoutConfig copyWith({double? entry, List<double>? multipliers}) =>
      PayoutConfig(entry: entry ?? this.entry, multipliers: multipliers ?? this.multipliers);
}
