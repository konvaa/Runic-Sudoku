import '../../grid/box_shape.dart';
import '../../grid/grid_coordinate.dart';
import '../../grid/grid_dimensions.dart';
import 'manual_puzzle.dart';
import 'runic_sudoku_snapshot.dart';

/// Mutable in-memory model of one Runic Sudoku game in progress.
///
/// Holds both the immutable puzzle definition (solution, givens, dimensions) and
/// the mutable progress (current grid, notes, counters, timing). It contains no
/// rule logic (that's [RunicSudokuRules]) and no persistence (that's the
/// controller + save service); it just stores and converts state.
class RunicSudokuState {
  // ---- Immutable puzzle definition ----
  final String levelId;
  final int seed;
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final List<List<int>> solutionGrid;
  final List<List<int>> givenCells;
  final String difficultyLabel;
  final Duration estimatedSolveTime;

  /// Entry point this session belongs to + stable puzzle identity (Phase
  /// 3.66.2). Campaign/daily leave [puzzleId] null.
  final PuzzleMode mode;
  final String? puzzleId;

  // ---- Mutable progress ----
  final List<List<int>> currentGrid;
  final List<List<Set<int>>> notes;
  GridCoordinate? selected;
  bool notesMode;
  int mistakesCount;
  int hintsUsed;
  int checksUsed;
  final DateTime startedAt;
  Duration elapsedTime;
  DateTime lastSavedAt;
  bool completed;
  Duration? actualSolveTime;

  RunicSudokuState({
    required this.levelId,
    required this.seed,
    required this.dimensions,
    required this.boxShape,
    required this.solutionGrid,
    required this.givenCells,
    required this.difficultyLabel,
    required this.estimatedSolveTime,
    required this.currentGrid,
    required this.notes,
    required this.startedAt,
    required this.elapsedTime,
    required this.lastSavedAt,
    this.mode = PuzzleMode.campaign,
    this.puzzleId,
    this.selected,
    this.notesMode = false,
    this.mistakesCount = 0,
    this.hintsUsed = 0,
    this.checksUsed = 0,
    this.completed = false,
    this.actualSolveTime,
  });

  /// Fresh state for a new game from a hand-authored puzzle.
  factory RunicSudokuState.fromPuzzle(
    ManualPuzzle p, {
    DateTime? now,
    PuzzleMode mode = PuzzleMode.campaign,
    String? puzzleId,
  }) {
    final ts = now ?? DateTime.now();
    return RunicSudokuState(
      levelId: p.levelId,
      seed: p.seed,
      dimensions: p.gridSize,
      boxShape: p.boxShape,
      solutionGrid: p.solutionGrid,
      givenCells: p.givenCells,
      difficultyLabel: p.difficultyLabel,
      estimatedSolveTime: p.estimatedSolveTime,
      currentGrid: p.initialCurrentGrid(),
      notes: _emptyNotes(p.gridSize),
      startedAt: ts,
      elapsedTime: Duration.zero,
      lastSavedAt: ts,
      mode: mode,
      puzzleId: puzzleId,
    );
  }

  /// Reconstructs state from a persisted snapshot (no ManualPuzzle needed).
  factory RunicSudokuState.fromSnapshot(RunicSudokuSnapshot s) {
    return RunicSudokuState(
      levelId: s.levelId,
      seed: s.seed,
      dimensions: s.gridSize,
      boxShape: s.boxShape,
      solutionGrid: s.solutionGrid,
      givenCells: s.givenCells,
      difficultyLabel: s.difficultyLabel,
      estimatedSolveTime: s.estimatedSolveTime,
      mode: s.mode,
      puzzleId: s.puzzleId,
      currentGrid: [for (final r in s.currentGrid) List<int>.from(r)],
      notes: [
        for (final row in s.notesGrid) [for (final cell in row) cell.toSet()],
      ],
      startedAt: s.startedAt,
      elapsedTime: s.elapsedTime,
      lastSavedAt: s.lastSavedAt,
      mistakesCount: s.mistakesCount,
      hintsUsed: s.hintsUsed,
      checksUsed: s.checksUsed,
      completed: s.completed,
      actualSolveTime: s.actualSolveTime,
    );
  }

  static List<List<Set<int>>> _emptyNotes(GridDimensions d) => [
        for (var r = 0; r < d.rows; r++)
          [for (var c = 0; c < d.cols; c++) <int>{}],
      ];

  bool isGiven(GridCoordinate c) => givenCells[c.row][c.col] != 0;

  int valueAt(GridCoordinate c) => currentGrid[c.row][c.col];

  Set<int> notesAt(GridCoordinate c) => notes[c.row][c.col];

  /// Serializes the live state to a persistable snapshot.
  RunicSudokuSnapshot toSnapshot({DateTime? savedAt}) {
    return RunicSudokuSnapshot(
      levelId: levelId,
      seed: seed,
      gridSize: dimensions,
      boxShape: boxShape,
      solutionGrid: solutionGrid,
      givenCells: givenCells,
      currentGrid: [for (final r in currentGrid) List<int>.from(r)],
      notesGrid: [
        for (final row in notes)
          [
            for (final cell in row) (cell.toList()..sort()),
          ],
      ],
      mistakesCount: mistakesCount,
      hintsUsed: hintsUsed,
      checksUsed: checksUsed,
      startedAt: startedAt,
      elapsedTime: elapsedTime,
      lastSavedAt: savedAt ?? DateTime.now(),
      completed: completed,
      difficultyLabel: difficultyLabel,
      estimatedSolveTime: estimatedSolveTime,
      actualSolveTime: actualSolveTime,
      mode: mode,
      puzzleId: puzzleId,
    );
  }
}
