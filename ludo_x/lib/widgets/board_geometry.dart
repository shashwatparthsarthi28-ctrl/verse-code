import 'dart:ui';

import '../engine/ludo_engine.dart';

/// 15x15 board geometry. Coordinates are in cell units; the centre of cell
/// (row r, col c) is Offset(c + 0.5, r + 0.5). Same track table that
/// functions/test/engine.test.js verifies (52 unique cells, diagonal steps only
/// at the four inner corners).
class BoardGeometry {
  static final List<List<int>> track = _buildTrack(); // [row, col]

  static List<List<int>> _buildTrack() {
    final cells = <List<int>>[];
    void run(int r, int c, int dr, int dc, int n) {
      for (var i = 0; i < n; i++) {
        cells.add([r + dr * i, c + dc * i]);
      }
    }

    run(6, 1, 0, 1, 5); // 0-4   Red start arm
    run(5, 6, -1, 0, 6); // 5-10
    run(0, 7, 0, 1, 2); // 11-12
    run(1, 8, 1, 0, 5); // 13-17 Green start
    run(6, 9, 0, 1, 6); // 18-23
    run(7, 14, 1, 0, 2); // 24-25
    run(8, 13, 0, -1, 5); // 26-30 Yellow start
    run(9, 8, 1, 0, 6); // 31-36
    run(14, 7, 0, -1, 2); // 37-38
    run(13, 6, -1, 0, 5); // 39-43 Blue start
    run(8, 5, 0, -1, 6); // 44-49
    run(7, 0, -1, 0, 2); // 50-51
    return cells;
  }

  /// Home column cells (progress 51..55) per seat, [row, col].
  static List<List<int>> homeColumn(int seat) {
    switch (seat) {
      case 0:
        return [for (var c = 1; c <= 5; c++) [7, c]];
      case 1:
        return [for (var r = 1; r <= 5; r++) [r, 7]];
      case 2:
        return [for (var c = 13; c >= 9; c--) [7, c]];
      default:
        return [for (var r = 13; r >= 9; r--) [r, 7]];
    }
  }

  /// Top-left yard corner (row, col) per seat.
  static List<int> yardOrigin(int seat) {
    switch (seat) {
      case 0:
        return [0, 0];
      case 1:
        return [0, 9];
      case 2:
        return [9, 9];
      default:
        return [9, 0];
    }
  }

  static Offset yardSlot(int seat, int token) {
    final o = yardOrigin(seat);
    final dx = (token % 2 == 0) ? 2.0 : 4.0;
    final dy = (token < 2) ? 2.0 : 4.0;
    return Offset(o[1] + dx, o[0] + dy);
  }

  /// Centre of a finished token inside the middle triangle of its colour.
  static Offset homeSlot(int seat, int token) {
    const dirs = [Offset(-1, 0), Offset(0, -1), Offset(1, 0), Offset(0, 1)];
    final d = dirs[seat];
    final perp = Offset(-d.dy, d.dx);
    final spread = (token - 1.5) * 0.2;
    return Offset(7.5, 7.5) + d * 0.78 + perp * spread;
  }

  /// Board position (cell units) of a token with the given progress.
  static Offset position(int seat, int token, int progress) {
    if (progress < 0) return yardSlot(seat, token);
    if (progress <= Rules.lastTrack) {
      final cell = track[(seat * 13 + progress) % Rules.trackLength];
      return Offset(cell[1] + 0.5, cell[0] + 0.5);
    }
    if (progress < Rules.home) {
      final cell = homeColumn(seat)[progress - 51];
      return Offset(cell[1] + 0.5, cell[0] + 0.5);
    }
    return homeSlot(seat, token);
  }
}
