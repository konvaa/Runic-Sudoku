import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';
import '../solver/difficulty_constants.dart';

/// Extra acceptance rules applied ONLY to Free Play generation (Phase 3.66) so
/// on-demand puzzles always look and start reasonably. Campaign pool puzzles
/// (assets/levels/runic_sudoku_levels.json) are NOT affected — these rules are
/// only consulted when [PuzzleGenerator.generate] is called with `freePlay:true`.
///
/// Pure functions — unit-testable without the generator.
class FreePlayGuardrails {
  const FreePlayGuardrails._();

  /// Returns true if [given] (0 = empty cell) is acceptable for [label].
  static bool passes(
    List<List<int>> given,
    DifficultyLabel label,
    GridDimensions dims,
    BoxShape box,
  ) {
    final emptyRows = _emptyRowCount(given, dims);
    final emptyCols = _emptyColCount(given, dims);

    final hard =
        label == DifficultyLabel.tricky || label == DifficultyLabel.deep;
    if (hard) {
      // Tricky/Deep: at most ONE fully-empty row or column in total, no empty box.
      if (emptyRows + emptyCols > 1) return false;
      if (_hasEmptyBox(given, dims, box)) return false;
    } else {
      // Quick/Normal: no fully-empty row or column at all.
      if (emptyRows > 0 || emptyCols > 0) return false;
    }

    // Every Free Play puzzle must have an obvious first move (a naked single
    // available from the start), so the board never opens with nowhere to begin.
    return _hasNakedSingle(given, dims, box);
  }

  static int _emptyRowCount(List<List<int>> g, GridDimensions d) {
    var n = 0;
    for (var r = 0; r < d.rows; r++) {
      var empty = true;
      for (var c = 0; c < d.cols; c++) {
        if (g[r][c] != 0) {
          empty = false;
          break;
        }
      }
      if (empty) n++;
    }
    return n;
  }

  static int _emptyColCount(List<List<int>> g, GridDimensions d) {
    var n = 0;
    for (var c = 0; c < d.cols; c++) {
      var empty = true;
      for (var r = 0; r < d.rows; r++) {
        if (g[r][c] != 0) {
          empty = false;
          break;
        }
      }
      if (empty) n++;
    }
    return n;
  }

  static bool _hasEmptyBox(List<List<int>> g, GridDimensions d, BoxShape box) {
    for (var b = 0; b < box.boxCount(d); b++) {
      final cells = box.coordinatesInBox(b, d);
      if (cells.every((c) => g[c.row][c.col] == 0)) return true;
    }
    return false;
  }

  /// True if at least one empty cell has exactly one candidate on the initial
  /// board (a naked single available immediately).
  static bool _hasNakedSingle(
    List<List<int>> g,
    GridDimensions d,
    BoxShape box,
  ) {
    final n = d.cols;
    final rowUsed = List<Set<int>>.generate(d.rows, (r) {
      final s = <int>{};
      for (var c = 0; c < d.cols; c++) {
        if (g[r][c] != 0) s.add(g[r][c]);
      }
      return s;
    });
    final colUsed = List<Set<int>>.generate(d.cols, (c) {
      final s = <int>{};
      for (var r = 0; r < d.rows; r++) {
        if (g[r][c] != 0) s.add(g[r][c]);
      }
      return s;
    });
    final boxUsed = List<Set<int>>.generate(box.boxCount(d), (b) {
      final s = <int>{};
      for (final coord in box.coordinatesInBox(b, d)) {
        final v = g[coord.row][coord.col];
        if (v != 0) s.add(v);
      }
      return s;
    });

    for (var r = 0; r < d.rows; r++) {
      for (var c = 0; c < d.cols; c++) {
        if (g[r][c] != 0) continue;
        final b = box.boxIndexFor(GridCoordinate(r, c), d);
        var count = 0;
        for (var v = 1; v <= n; v++) {
          if (!rowUsed[r].contains(v) &&
              !colUsed[c].contains(v) &&
              !boxUsed[b].contains(v)) {
            count++;
            if (count > 1) break;
          }
        }
        if (count == 1) return true;
      }
    }
    return false;
  }
}
