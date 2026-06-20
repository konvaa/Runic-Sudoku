import 'dart:ui' show Offset, Size;

import 'grid_coordinate.dart';
import 'grid_dimensions.dart';

/// Translates a local tap position on the board into a [GridCoordinate].
///
/// This is the single place that knows the pixel-to-cell math, so the board
/// widget and any future input source (keyboard, gamepad cursor) can reuse it.
/// It is sudoku-agnostic.
class GridInputMapper {
  final GridDimensions dimensions;

  const GridInputMapper(this.dimensions);

  /// Returns the coordinate under [localOffset] given the board's [boardSize],
  /// or null if the tap is outside the board.
  GridCoordinate? coordinateForOffset(Offset localOffset, Size boardSize) {
    if (boardSize.width <= 0 || boardSize.height <= 0) return null;
    if (localOffset.dx < 0 ||
        localOffset.dy < 0 ||
        localOffset.dx >= boardSize.width ||
        localOffset.dy >= boardSize.height) {
      return null;
    }
    final cellW = boardSize.width / dimensions.cols;
    final cellH = boardSize.height / dimensions.rows;
    final col =
        (localOffset.dx / cellW).floor().clamp(0, dimensions.cols - 1).toInt();
    final row =
        (localOffset.dy / cellH).floor().clamp(0, dimensions.rows - 1).toInt();
    return GridCoordinate(row, col);
  }
}
