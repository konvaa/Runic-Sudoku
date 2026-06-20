import 'grid_coordinate.dart';
import 'grid_dimensions.dart';

/// Describes the rectangular "box" subdivision of a grid as pure data.
///
/// IMPORTANT: this is a Grid Core concept (a visual/structural partition of the
/// grid). It deliberately knows nothing about sudoku rules. Knowing that "each
/// box must contain 1..6 exactly once" is the Runic Sudoku module's job.
///
/// NOTE: Flutter's painting library also exports a `BoxShape` enum. Files that
/// import both `package:flutter/material.dart` and this file must hide the
/// Flutter one: `import 'package:flutter/material.dart' hide BoxShape;`.
class BoxShape {
  /// Number of rows a single box spans.
  final int rows;

  /// Number of columns a single box spans.
  final int cols;

  const BoxShape({required this.rows, required this.cols});

  /// How many cells a single box contains.
  int get cellCount => rows * cols;

  /// How many boxes fit horizontally across the given grid.
  int boxesPerRow(GridDimensions dims) => dims.cols ~/ cols;

  /// How many boxes fit vertically down the given grid.
  int boxesPerColumn(GridDimensions dims) => dims.rows ~/ rows;

  /// Total number of boxes in the given grid.
  int boxCount(GridDimensions dims) =>
      boxesPerRow(dims) * boxesPerColumn(dims);

  /// Returns true if [dims] tiles evenly into boxes of this shape.
  bool fits(GridDimensions dims) =>
      dims.rows % rows == 0 && dims.cols % cols == 0;

  /// The linear box index (row-major over boxes) that [coord] belongs to,
  /// for a grid of [dims].
  int boxIndexFor(GridCoordinate coord, GridDimensions dims) {
    final boxRow = coord.row ~/ rows;
    final boxCol = coord.col ~/ cols;
    return boxRow * boxesPerRow(dims) + boxCol;
  }

  /// All coordinates belonging to the box with [boxIndex] for [dims].
  List<GridCoordinate> coordinatesInBox(int boxIndex, GridDimensions dims) {
    final perRow = boxesPerRow(dims);
    final boxRow = boxIndex ~/ perRow;
    final boxCol = boxIndex % perRow;
    final startRow = boxRow * rows;
    final startCol = boxCol * cols;
    return [
      for (var r = startRow; r < startRow + rows; r++)
        for (var c = startCol; c < startCol + cols; c++) GridCoordinate(r, c),
    ];
  }

  /// True when [coord] sits on the left edge of a box (used for thick borders).
  bool isBoxLeftEdge(GridCoordinate coord) => coord.col % cols == 0;

  /// True when [coord] sits on the top edge of a box.
  bool isBoxTopEdge(GridCoordinate coord) => coord.row % rows == 0;

  /// Token form used in serialization, e.g. "2x3".
  String toToken() => '${rows}x$cols';

  factory BoxShape.parse(String token) {
    final parts = token.toLowerCase().split('x');
    if (parts.length != 2) {
      throw FormatException('Invalid box shape token: "$token"');
    }
    return BoxShape(rows: int.parse(parts[0]), cols: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() => {'rows': rows, 'cols': cols};

  factory BoxShape.fromJson(Map<String, dynamic> json) =>
      BoxShape(rows: json['rows'] as int, cols: json['cols'] as int);

  @override
  bool operator ==(Object other) =>
      other is BoxShape && other.rows == rows && other.cols == cols;

  @override
  int get hashCode => Object.hash(rows, cols);

  @override
  String toString() => 'BoxShape($rows x $cols)';
}
