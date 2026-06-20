import 'dart:math';

import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';

/// Step (a) of the pipeline: produce a complete, valid grid via randomized
/// backtracking. Parametric over grid size / box shape; values are 1..n where
/// n = number of columns.
class FullGridGenerator {
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final int _n;
  final int _rows;
  final int _cols;
  final int _size;
  final int _full;
  late final List<int> _boxOf;

  FullGridGenerator({required this.dimensions, required this.boxShape})
      : _n = dimensions.cols,
        _rows = dimensions.rows,
        _cols = dimensions.cols,
        _size = dimensions.rows * dimensions.cols,
        _full = (1 << dimensions.cols) - 1 {
    _boxOf = List<int>.generate(_size, (i) {
      final r = i ~/ _cols;
      final c = i % _cols;
      return boxShape.boxIndexFor(GridCoordinate(r, c), dimensions);
    });
  }

  /// Returns a freshly filled valid grid. Deterministic for a given [rng].
  List<List<int>> generate(Random rng) {
    final board = List<int>.filled(_size, 0);
    final rowMask = List<int>.filled(_rows, 0);
    final colMask = List<int>.filled(_cols, 0);
    final boxMask = List<int>.filled(boxShape.boxCount(dimensions), 0);

    bool fill(int idx) {
      if (idx == _size) return true;
      final r = idx ~/ _cols;
      final c = idx % _cols;
      final b = _boxOf[idx];
      final available = _full & ~(rowMask[r] | colMask[c] | boxMask[b]);
      final values = _shuffledValues(available, rng);
      for (final v in values) {
        final bit = 1 << (v - 1);
        board[idx] = v;
        rowMask[r] |= bit;
        colMask[c] |= bit;
        boxMask[b] |= bit;
        if (fill(idx + 1)) return true;
        board[idx] = 0;
        rowMask[r] &= ~bit;
        colMask[c] &= ~bit;
        boxMask[b] &= ~bit;
      }
      return false;
    }

    fill(0);
    return [
      for (var r = 0; r < _rows; r++)
        [for (var c = 0; c < _cols; c++) board[r * _cols + c]],
    ];
  }

  List<int> _shuffledValues(int mask, Random rng) {
    final values = <int>[];
    for (var v = 1; v <= _n; v++) {
      if ((mask & (1 << (v - 1))) != 0) values.add(v);
    }
    values.shuffle(rng);
    return values;
  }
}
