import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';

/// Fast solution-counter for uniqueness checking during generation
/// (Phase 0 §4.1).
///
/// Optimised purely for speed: bitmask constraint propagation + MRV (minimum
/// remaining values) backtracking. It does NOT log techniques or compute
/// difficulty. [countSolutions] returns 0, 1, or 2 — where 2 means "two or
/// more" — and stops the instant a second solution is found.
///
/// Parametric over [GridDimensions] + [BoxShape]; nothing is hardcoded to 6×6.
/// Values are 1..n where n = number of columns (square sudoku grid).
///
/// Reuse: a single instance can be reused across the hundreds of removal checks
/// in one generation. The per-cell box index is precomputed once in the
/// constructor; each [countSolutions] call allocates O(n²) working arrays (one
/// flat board + three small mask lists). For MVP grid sizes this is negligible;
/// see PHASE2_NOTES.md "performance" for why an incremental structure was
/// deliberately not built yet.
class FastUniquenessSolver {
  final GridDimensions dimensions;
  final BoxShape boxShape;

  late final int _n;
  late final int _rows;
  late final int _cols;
  late final int _size;
  late final int _full;
  late final List<int> _boxOf;
  late final int _boxCount;

  int _nodes = 0;
  int _solutions = 0;
  int _maxSolutions = 2;

  late List<int> _board;
  late List<int> _rowMask;
  late List<int> _colMask;
  late List<int> _boxMask;

  /// Branch nodes visited in the last [countSolutions] call. Useful to prove the
  /// search short-circuits rather than enumerating the whole tree.
  int get nodesVisited => _nodes;

  FastUniquenessSolver({required this.dimensions, required this.boxShape}) {
    _rows = dimensions.rows;
    _cols = dimensions.cols;
    _n = dimensions.cols;
    _size = _rows * _cols;
    _full = (1 << _n) - 1;
    _boxCount = boxShape.boxCount(dimensions);
    _boxOf = List<int>.generate(_size, (i) {
      final r = i ~/ _cols;
      final c = i % _cols;
      return boxShape.boxIndexFor(GridCoordinate(r, c), dimensions);
    });
  }

  /// Counts solutions of [grid] (0 = empty cell), capped at [maxSolutions].
  /// Returns 0 (unsatisfiable), 1 (unique), or up to [maxSolutions].
  int countSolutions(List<List<int>> grid, {int maxSolutions = 2}) {
    _maxSolutions = maxSolutions;
    _nodes = 0;
    _solutions = 0;
    _board = List<int>.filled(_size, 0);
    _rowMask = List<int>.filled(_rows, 0);
    _colMask = List<int>.filled(_cols, 0);
    _boxMask = List<int>.filled(_boxCount, 0);

    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final v = grid[r][c];
        if (v == 0) continue;
        final bit = 1 << (v - 1);
        final idx = r * _cols + c;
        final b = _boxOf[idx];
        if ((_rowMask[r] & bit) != 0 ||
            (_colMask[c] & bit) != 0 ||
            (_boxMask[b] & bit) != 0) {
          return 0; // conflicting givens -> unsatisfiable
        }
        _board[idx] = v;
        _rowMask[r] |= bit;
        _colMask[c] |= bit;
        _boxMask[b] |= bit;
      }
    }

    _search();
    return _solutions;
  }

  void _search() {
    // Minimum-remaining-values selection.
    var bestIdx = -1;
    var bestCands = 0;
    var bestCount = _n + 1;
    for (var idx = 0; idx < _size; idx++) {
      if (_board[idx] != 0) continue;
      final r = idx ~/ _cols;
      final c = idx % _cols;
      final used = _rowMask[r] | _colMask[c] | _boxMask[_boxOf[idx]];
      final cands = _full & ~used;
      if (cands == 0) return; // dead end, prune
      final cnt = _popcount(cands);
      if (cnt < bestCount) {
        bestCount = cnt;
        bestIdx = idx;
        bestCands = cands;
        if (cnt == 1) break;
      }
    }

    if (bestIdx == -1) {
      _solutions++; // complete grid -> one solution
      return;
    }

    _nodes++;
    final r = bestIdx ~/ _cols;
    final c = bestIdx % _cols;
    final b = _boxOf[bestIdx];
    var cands = bestCands;
    while (cands != 0) {
      final bit = cands & (-cands); // lowest set bit
      cands ^= bit;
      _board[bestIdx] = _valueOfBit(bit);
      _rowMask[r] |= bit;
      _colMask[c] |= bit;
      _boxMask[b] |= bit;

      _search();

      _board[bestIdx] = 0;
      _rowMask[r] &= ~bit;
      _colMask[c] &= ~bit;
      _boxMask[b] &= ~bit;

      if (_solutions >= _maxSolutions) return; // short-circuit
    }
  }

  static int _popcount(int x) {
    var count = 0;
    var v = x;
    while (v != 0) {
      v &= v - 1;
      count++;
    }
    return count;
  }

  static int _valueOfBit(int bit) {
    var v = 0;
    var b = bit;
    while (b > 1) {
      b >>= 1;
      v++;
    }
    return v + 1;
  }
}
