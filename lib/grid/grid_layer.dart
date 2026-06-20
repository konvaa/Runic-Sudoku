import 'grid_coordinate.dart';
import 'grid_dimensions.dart';

/// A typed, row-major 2D data layer over a grid.
///
/// Grid Core stores values without interpreting them. A sudoku game might use a
/// `GridLayer<int>` for placed values and a `GridLayer<Set<int>>` for notes; a
/// future word game might use a `GridLayer<String>`. The grid never asks what
/// the values *mean*.
///
/// `null` represents "empty" for any cell type.
class GridLayer<T> {
  final GridDimensions dimensions;
  final List<T?> _cells;

  GridLayer(this.dimensions)
      : _cells = List<T?>.filled(dimensions.cellCount, null);

  GridLayer._(this.dimensions, this._cells);

  int _indexOf(GridCoordinate c) {
    assert(dimensions.contains(c), 'Coordinate $c outside $dimensions');
    return c.row * dimensions.cols + c.col;
  }

  T? valueAt(GridCoordinate c) => _cells[_indexOf(c)];

  void setValue(GridCoordinate c, T? value) => _cells[_indexOf(c)] = value;

  void clear(GridCoordinate c) => _cells[_indexOf(c)] = null;

  bool isEmptyAt(GridCoordinate c) => _cells[_indexOf(c)] == null;

  /// A deep-ish copy. Values are copied by reference; supply [copyValue] for
  /// mutable value types (e.g. Set) that must not be shared.
  GridLayer<T> copy({T? Function(T? value)? copyValue}) {
    final cells = copyValue == null
        ? List<T?>.from(_cells)
        : _cells.map(copyValue).toList();
    return GridLayer<T>._(dimensions, cells);
  }

  /// Builds a layer from a row-major nested list (e.g. parsed JSON).
  static GridLayer<T> fromRows<T>(
    GridDimensions dimensions,
    List<List<T?>> rows,
  ) {
    final layer = GridLayer<T>(dimensions);
    for (var r = 0; r < dimensions.rows; r++) {
      for (var c = 0; c < dimensions.cols; c++) {
        layer.setValue(GridCoordinate(r, c), rows[r][c]);
      }
    }
    return layer;
  }

  /// Row-major nested list view, convenient for serialization.
  List<List<T?>> toRows() => [
        for (var r = 0; r < dimensions.rows; r++)
          [
            for (var c = 0; c < dimensions.cols; c++)
              valueAt(GridCoordinate(r, c)),
          ],
      ];
}
