import '../../grid/box_shape.dart';
import '../../grid/grid_dimensions.dart';

/// A hand-authored puzzle fixture for Phase 1 (no generator/solver involved).
///
/// `givenCells` are the clues (0 = empty). `solutionGrid` is the full answer.
/// The initial player board is a deep copy of `givenCells`.
class ManualPuzzle {
  final String levelId;
  final int seed;
  final GridDimensions gridSize;
  final BoxShape boxShape;
  final List<List<int>> solutionGrid;
  final List<List<int>> givenCells;
  final String difficultyLabel;
  final Duration estimatedSolveTime;

  const ManualPuzzle({
    required this.levelId,
    required this.seed,
    required this.gridSize,
    required this.boxShape,
    required this.solutionGrid,
    required this.givenCells,
    required this.difficultyLabel,
    required this.estimatedSolveTime,
  });

  /// A fresh, independent copy of the givens to use as the starting board.
  List<List<int>> initialCurrentGrid() =>
      [for (final row in givenCells) List<int>.from(row)];

  int get blankCount {
    var n = 0;
    for (final row in givenCells) {
      for (final v in row) {
        if (v == 0) n++;
      }
    }
    return n;
  }
}

const _sixBySix = GridDimensions(rows: 6, cols: 6);
const _twoByThree = BoxShape(rows: 2, cols: 3);

/// A) Almost-finished puzzle. Four empty cells in the bottom-right box — fast to
/// complete, ideal for exercising win condition + save/load + level-complete.
const ManualPuzzle quickTestPuzzle = ManualPuzzle(
  levelId: 'rs_quick_test',
  seed: 1001,
  gridSize: _sixBySix,
  boxShape: _twoByThree,
  difficultyLabel: 'Tutorial',
  estimatedSolveTime: Duration(minutes: 1),
  solutionGrid: [
    [1, 2, 3, 4, 5, 6],
    [4, 5, 6, 1, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 4, 5],
    [6, 4, 5, 3, 1, 2],
  ],
  givenCells: [
    [1, 2, 3, 4, 5, 6],
    [4, 5, 6, 1, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 0, 0],
    [6, 4, 5, 3, 0, 0],
  ],
);

/// B) Sparser puzzle (20 blanks) for testing notes/candidates, live validation,
/// and ordinary play.
const ManualPuzzle notesTestPuzzle = ManualPuzzle(
  levelId: 'rs_notes_test',
  seed: 1002,
  gridSize: _sixBySix,
  boxShape: _twoByThree,
  difficultyLabel: 'Easy',
  estimatedSolveTime: Duration(minutes: 6),
  solutionGrid: [
    [6, 5, 4, 3, 2, 1],
    [3, 2, 1, 6, 5, 4],
    [5, 4, 6, 2, 1, 3],
    [2, 1, 3, 5, 4, 6],
    [4, 6, 5, 1, 3, 2],
    [1, 3, 2, 4, 6, 5],
  ],
  givenCells: [
    [6, 0, 0, 3, 0, 1],
    [0, 2, 0, 0, 5, 0],
    [5, 0, 6, 0, 0, 3],
    [2, 0, 0, 5, 0, 6],
    [0, 6, 0, 0, 3, 0],
    [1, 0, 2, 0, 0, 5],
  ],
);

/// All Phase 1 manual puzzles, in level-select order.
const List<ManualPuzzle> manualPuzzles = [quickTestPuzzle, notesTestPuzzle];
