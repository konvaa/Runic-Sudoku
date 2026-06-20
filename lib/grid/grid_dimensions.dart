import 'grid_coordinate.dart';

/// The size of a grid in cells. Agnostic to box layout and game rules.
class GridDimensions {
  final int rows;
  final int cols;

  const GridDimensions({required this.rows, required this.cols});

  /// Square grid convenience constructor (e.g. 6x6).
  const GridDimensions.square(int size)
      : rows = size,
        cols = size;

  int get cellCount => rows * cols;

  bool contains(GridCoordinate c) =>
      c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols;

  /// Iterates every coordinate in row-major order.
  Iterable<GridCoordinate> get coordinates sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield GridCoordinate(r, c);
      }
    }
  }

  /// Token form used in serialization, e.g. "6x6".
  String toToken() => '${rows}x$cols';

  factory GridDimensions.parse(String token) {
    final parts = token.toLowerCase().split('x');
    if (parts.length != 2) {
      throw FormatException('Invalid grid size token: "$token"');
    }
    return GridDimensions(rows: int.parse(parts[0]), cols: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() => {'rows': rows, 'cols': cols};

  factory GridDimensions.fromJson(Map<String, dynamic> json) =>
      GridDimensions(rows: json['rows'] as int, cols: json['cols'] as int);

  @override
  bool operator ==(Object other) =>
      other is GridDimensions && other.rows == rows && other.cols == cols;

  @override
  int get hashCode => Object.hash(rows, cols);

  @override
  String toString() => 'GridDimensions($rows x $cols)';
}
