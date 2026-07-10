import '../../grid/box_shape.dart';
import '../../grid/grid_coordinate.dart';
import '../../grid/grid_dimensions.dart';

/// Pure sudoku rule logic for the Runic Sudoku module.
///
/// This is the ONLY place that knows row/column/box uniqueness rules. Grid Core
/// never imports this. Grids are `List<List<int>>` in row-major order where 0
/// means "empty" and 1..n are placed values.
///
/// This file is intentionally Flutter-free (pure Dart) so the Phase 2 solver and
/// generator can reuse it without pulling in any UI dependency. Symbol-set
/// validation, which needs the (Flutter-importing) `SymbolSet`, lives in the
/// `runic_sudoku_symbol_validation.dart` extension instead. See PHASE2_NOTES.md.
class RunicSudokuRules {
  final GridDimensions dimensions;
  final BoxShape boxShape;

  /// Explicit rune count, when supplied to the constructor; null means "derive
  /// from [dimensions]". Stored nullable so the const constructor can keep its
  /// existing call sites unchanged (a const initializer cannot read
  /// `dimensions.cols`). Read via [runeCount], never directly.
  final int? _explicitRuneCount;

  const RunicSudokuRules({
    required this.dimensions,
    required this.boxShape,
    int? runeCount,
  }) : _explicitRuneCount = runeCount;

  /// Standard 6x6 / 2x3 configuration used by the first game.
  static const sixBySix = RunicSudokuRules(
    dimensions: GridDimensions(rows: 6, cols: 6),
    boxShape: BoxShape(rows: 2, cols: 3),
  );

  /// Chapter 1's rune count (6×6 board → 6 runes). Named here — next to the
  /// [sixBySix] preset that defines Chapter 1's board — so UI copy can
  /// reference it instead of hardcoding a literal 6. Must equal
  /// `sixBySix.runeCount`.
  static const int chapter1RuneCount = 6;

  /// Number of distinct rune values (1..runeCount) legal on this board.
  ///
  /// Defaults to `dimensions.cols`, which is the correct value for every
  /// square sudoku board (6×6 → 6, 9×9 → 9). Making the count an explicit,
  /// named concept (instead of `dimensions.cols` sprinkled at call sites) is
  /// the first step toward a future `BoardConfig`; see
  /// dev_notes/fable_step0_inventory_result.md.
  int get runeCount {
    assert(
      _explicitRuneCount == null || _explicitRuneCount == dimensions.cols,
      'runeCount ($_explicitRuneCount) must equal dimensions.cols '
      '(${dimensions.cols}) for a square sudoku board.',
    );
    return _explicitRuneCount ?? dimensions.cols;
  }

  int get maxValue => runeCount; // 1..maxValue are legal values.

  // ---- Live-constraint validation -----------------------------------------

  /// Returns true if placing nothing else, no unit (row/col/box) currently
  /// contains a duplicate non-zero value.
  bool hasNoConflicts(List<List<int>> grid) => conflicts(grid).isEmpty;

  /// Coordinates that participate in at least one row/column/box duplicate.
  /// Empty cells (0) are never reported.
  Set<GridCoordinate> conflicts(List<List<int>> grid) {
    final bad = <GridCoordinate>{};

    void scan(List<GridCoordinate> unit) {
      final seen = <int, List<GridCoordinate>>{};
      for (final c in unit) {
        final v = grid[c.row][c.col];
        if (v == 0) continue;
        seen.putIfAbsent(v, () => []).add(c);
      }
      for (final entry in seen.values) {
        if (entry.length > 1) bad.addAll(entry);
      }
    }

    for (var r = 0; r < dimensions.rows; r++) {
      scan([for (var c = 0; c < dimensions.cols; c++) GridCoordinate(r, c)]);
    }
    for (var c = 0; c < dimensions.cols; c++) {
      scan([for (var r = 0; r < dimensions.rows; r++) GridCoordinate(r, c)]);
    }
    for (var b = 0; b < boxShape.boxCount(dimensions); b++) {
      scan(boxShape.coordinatesInBox(b, dimensions));
    }
    return bad;
  }

  /// True if [value] can be placed at [coord] without creating a row/col/box
  /// duplicate (live-constraint check, ignores the solution).
  bool canPlace(List<List<int>> grid, GridCoordinate coord, int value) {
    if (value < 1 || value > maxValue) return false;
    for (var c = 0; c < dimensions.cols; c++) {
      if (c != coord.col && grid[coord.row][c] == value) return false;
    }
    for (var r = 0; r < dimensions.rows; r++) {
      if (r != coord.row && grid[r][coord.col] == value) return false;
    }
    final box = boxShape.boxIndexFor(coord, dimensions);
    for (final c in boxShape.coordinatesInBox(box, dimensions)) {
      if (c != coord && grid[c.row][c.col] == value) return false;
    }
    return true;
  }

  // ---- Solution-based validation ------------------------------------------

  /// True if [value] equals the solution value at [coord].
  bool isCorrectPlacement(
    List<List<int>> solution,
    GridCoordinate coord,
    int value,
  ) =>
      solution[coord.row][coord.col] == value;

  /// Cells in [current] whose non-zero value disagrees with [solution].
  Set<GridCoordinate> mistakesAgainstSolution(
    List<List<int>> current,
    List<List<int>> solution,
  ) {
    final bad = <GridCoordinate>{};
    for (final c in dimensions.coordinates) {
      final v = current[c.row][c.col];
      if (v != 0 && v != solution[c.row][c.col]) bad.add(c);
    }
    return bad;
  }

  // ---- Completion ----------------------------------------------------------

  /// Every cell filled (no zeros).
  bool isFilled(List<List<int>> grid) {
    for (final c in dimensions.coordinates) {
      if (grid[c.row][c.col] == 0) return false;
    }
    return true;
  }

  /// Filled AND internally consistent (no duplicates). Independent of solution.
  bool isCompleteAndValid(List<List<int>> grid) =>
      isFilled(grid) && conflicts(grid).isEmpty;

  /// Win condition per spec: current grid exactly equals the solution grid.
  bool isWin(List<List<int>> current, List<List<int>> solution) {
    for (final c in dimensions.coordinates) {
      if (current[c.row][c.col] != solution[c.row][c.col]) return false;
    }
    return true;
  }
}
