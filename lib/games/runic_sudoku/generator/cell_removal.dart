import 'dart:math';

import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';
import '../solver/fast_uniqueness_solver.dart';

/// Step (b) of the pipeline: remove cells while keeping the puzzle uniquely
/// solvable. A single [FastUniquenessSolver] is reused across all checks in a
/// run (it resets its working state per call).
class CellRemover {
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final FastUniquenessSolver _uniqueness;

  CellRemover({required this.dimensions, required this.boxShape})
      : _uniqueness =
            FastUniquenessSolver(dimensions: dimensions, boxShape: boxShape);

  /// Removes cells from a complete [full] grid in random order.
  ///
  /// A removal is kept only if the puzzle stays uniquely solvable AND (when
  /// provided) [accept] returns true for the resulting puzzle. Stops once
  /// [targetBlanks] is reached or no cell remains removable.
  ///
  /// [accept] lets the caller add constraints (e.g. "still solvable with zero
  /// decision points" for Quick) without this class knowing about difficulty.
  List<List<int>> remove(
    List<List<int>> full,
    Random rng, {
    required int targetBlanks,
    bool Function(List<List<int>> puzzle)? accept,
  }) {
    final puzzle = [for (final row in full) List<int>.from(row)];
    final order = [
      for (var r = 0; r < dimensions.rows; r++)
        for (var c = 0; c < dimensions.cols; c++) GridCoordinate(r, c),
    ]..shuffle(rng);

    var blanks = 0;
    for (final coord in order) {
      if (blanks >= targetBlanks) break;
      final saved = puzzle[coord.row][coord.col];
      if (saved == 0) continue;

      puzzle[coord.row][coord.col] = 0;
      final stillUnique =
          _uniqueness.countSolutions(puzzle, maxSolutions: 2) == 1;
      final ok = stillUnique && (accept == null || accept(puzzle));
      if (ok) {
        blanks++;
      } else {
        puzzle[coord.row][coord.col] = saved; // revert
      }
    }
    return puzzle;
  }
}
