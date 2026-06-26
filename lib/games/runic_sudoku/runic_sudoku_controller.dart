import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/save/save_service.dart';
import '../../core/save/save_trigger_type.dart';
import '../../grid/grid_coordinate.dart';
import 'manual_puzzle.dart';
import 'runic_sudoku_rules.dart';
import 'runic_sudoku_snapshot.dart';
import 'runic_sudoku_state.dart';
import 'solver/human_like_solver.dart';
import 'solver/solver_step.dart';

/// Orchestrates one Runic Sudoku game: applies user actions to [RunicSudokuState]
/// using [RunicSudokuRules], persists complete snapshots via [SaveService], and
/// reports analytics. A plain [ChangeNotifier] — no DI framework, no BLoC.
class RunicSudokuController extends ChangeNotifier {
  final RunicSudokuState state;
  final RunicSudokuRules rules;
  final SaveService saveService;
  final AnalyticsService analytics;

  /// Ordered "logical" solving steps for THIS puzzle (from the human-like solver,
  /// computed once at load). Drives the hint system. May be empty if unavailable.
  final List<SolverStep> solverSteps;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Set<GridCoordinate> _errorCells = {};

  RunicSudokuController({
    required this.state,
    required this.saveService,
    required this.analytics,
    this.solverSteps = const <SolverStep>[],
    RunicSudokuRules? rules,
  }) : rules = rules ??
            RunicSudokuRules(
                dimensions: state.dimensions, boxShape: state.boxShape);

  /// Loads an existing save for [puzzle] or starts a fresh game.
  ///
  /// When [fresh] is true, any existing save under this level id is ignored and a
  /// brand-new game is started (used by Free Play, whose puzzles reuse one save
  /// slot per difficulty and must never resume a previous, different puzzle).
  static Future<RunicSudokuController> loadOrCreate({
    required ManualPuzzle puzzle,
    required SaveService saveService,
    required AnalyticsService analytics,
    bool fresh = false,
    PuzzleMode mode = PuzzleMode.campaign,
    String? puzzleId,
  }) async {
    // Daily / Free Play use a single shared slot, so a saved snapshot there might
    // belong to a DIFFERENT puzzle (e.g. yesterday's daily). Only resume it when
    // its givens match the requested puzzle; otherwise start fresh + overwrite.
    final key = saveKeyFor(mode, puzzle.levelId);
    final raw = fresh ? null : await saveService.load(key);
    var startedFresh = raw == null;
    final RunicSudokuState state;
    if (raw != null) {
      final snap = RunicSudokuSnapshot.fromJson(raw);
      if (_sameGrid(snap.givenCells, puzzle.givenCells)) {
        state = RunicSudokuState.fromSnapshot(snap);
      } else {
        state = RunicSudokuState.fromPuzzle(puzzle, mode: mode, puzzleId: puzzleId);
        startedFresh = true;
      }
    } else {
      state = RunicSudokuState.fromPuzzle(puzzle, mode: mode, puzzleId: puzzleId);
    }

    // The hint system needs the logical solving order. The pool JSON does not
    // store solver_steps_log, so recompute it once here from the original puzzle
    // (givens + solution). Cheap; runs once per level open. See PHASE3_NOTES.md.
    final steps = HumanLikeSolver(
      dimensions: puzzle.gridSize,
      boxShape: puzzle.boxShape,
    ).analyze(puzzle.givenCells, puzzle.solutionGrid).solverStepsLog;

    final controller = RunicSudokuController(
      state: state,
      saveService: saveService,
      analytics: analytics,
      solverSteps: steps,
    );
    if (startedFresh) {
      await controller.save(SaveTriggerType.levelStart);
    }
    return controller;
  }

  // ---- Read-only view for the UI -----------------------------------------

  GridCoordinate? get selected => state.selected;
  bool get notesMode => state.notesMode;
  bool get completed => state.completed;
  int get mistakesCount => state.mistakesCount;
  int get hintsUsed => state.hintsUsed;
  int get checksUsed => state.checksUsed;

  /// True while the puzzle's single free mistake-check is still available.
  bool get hasFreeCheck => state.checksUsed == 0;

  Set<GridCoordinate> get errorCells => Set.unmodifiable(_errorCells);

  /// Total elapsed play time (persisted base + current running segment).
  Duration get elapsed => state.elapsedTime + _stopwatch.elapsed;

  // ---- Lifecycle / timing -------------------------------------------------

  /// Call when the screen becomes active. Starts the play clock.
  void resume() {
    if (state.completed) return;
    if (!_stopwatch.isRunning) _stopwatch.start();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners(); // refresh the on-screen clock once per second
    });
  }

  /// Call on app pause / screen leave. Persists a snapshot (app_pause).
  Future<void> pause() async {
    _ticker?.cancel();
    _ticker = null;
    if (_stopwatch.isRunning) _stopwatch.stop();
    await save(SaveTriggerType.appPause);
  }

  void _foldElapsedIntoState() {
    final running = _stopwatch.isRunning;
    state.elapsedTime += _stopwatch.elapsed;
    _stopwatch.reset();
    if (running && !state.completed) _stopwatch.start();
  }

  // ---- User actions -------------------------------------------------------

  void selectCell(GridCoordinate coord) {
    if (!state.dimensions.contains(coord)) return;
    state.selected = coord;
    notifyListeners();
  }

  /// Enters [value] (1..n) at the selected cell, or toggles it as a note when
  /// notes mode is on.
  Future<void> inputValue(int value) async {
    final coord = state.selected;
    if (coord == null || state.isGiven(coord)) return;
    if (value < 1 || value > rules.maxValue) return;

    if (state.notesMode) {
      // Notes only make sense on empty cells.
      if (state.valueAt(coord) != 0) return;
      final notes = state.notesAt(coord);
      notes.contains(value) ? notes.remove(value) : notes.add(value);
      notifyListeners();
      await save(SaveTriggerType.notesChanged);
      return;
    }

    // Toggle off if re-entering the same value.
    if (state.valueAt(coord) == value) {
      state.currentGrid[coord.row][coord.col] = 0;
    } else {
      state.currentGrid[coord.row][coord.col] = value;
      state.notesAt(coord).clear();
      if (!rules.isCorrectPlacement(state.solutionGrid, coord, value)) {
        state.mistakesCount++;
      }
    }
    _errorCells = {};
    notifyListeners();
    await save(SaveTriggerType.placementComplete);
    await _checkWin();
  }

  /// Clears the selected cell's value and notes.
  Future<void> erase() async {
    final coord = state.selected;
    if (coord == null || state.isGiven(coord)) return;
    state.currentGrid[coord.row][coord.col] = 0;
    state.notesAt(coord).clear();
    _errorCells = {};
    notifyListeners();
    await save(SaveTriggerType.placementComplete);
  }

  /// True if the player has entered any value (in a non-given cell) or any note.
  bool get hasPlayerProgress {
    for (final c in state.dimensions.coordinates) {
      if (!state.isGiven(c) && state.currentGrid[c.row][c.col] != 0) return true;
      if (state.notesAt(c).isNotEmpty) return true;
    }
    return false;
  }

  /// Resets the player's solution: clears every player-entered value and all
  /// notes, keeping the given clues. Deliberately does NOT touch the timer,
  /// mistakes, hints, or checks — it's "clear my work on this puzzle", not a
  /// level restart. No-op once the puzzle is solved.
  Future<void> resetBoard() async {
    if (state.completed) return;
    for (final c in state.dimensions.coordinates) {
      if (!state.isGiven(c)) state.currentGrid[c.row][c.col] = 0;
      state.notesAt(c).clear();
    }
    _errorCells = {};
    notifyListeners();
    await save(SaveTriggerType.placementComplete);
  }

  void toggleNotesMode() {
    state.notesMode = !state.notesMode;
    notifyListeners();
  }

  /// Highlights cells whose value disagrees with the solution and counts the
  /// check. Does not change [mistakesCount] (that counts wrong placements as they
  /// happen). Free/rewarded gating is handled by the caller via [hasFreeCheck].
  Future<void> checkMistakes() async {
    state.checksUsed++;
    _errorCells =
        rules.mistakesAgainstSolution(state.currentGrid, state.solutionGrid);
    notifyListeners();
    await save(SaveTriggerType.mistakeChecked);
  }

  /// Reveals the NEXT logical step from [solverSteps] — the first step whose cell
  /// the player has not yet filled correctly (empty or wrong). Falls back to any
  /// empty non-given cell from the solution if the log is missing/exhausted.
  /// Returns the revealed coordinate, or null if nothing was revealed.
  ///
  /// The rewarded-ad gating is performed by the caller (the screen owns the
  /// `AdsService`); this only performs the reveal once a reward is granted.
  Future<GridCoordinate?> revealNextHint() async {
    GridCoordinate? target;
    int? value;

    for (final step in solverSteps) {
      final c = step.cell;
      if (state.currentGrid[c.row][c.col] != state.solutionGrid[c.row][c.col]) {
        target = c;
        value = step.value;
        break;
      }
    }

    if (target == null) {
      // Fallback: first empty non-given cell (log missing or exhausted).
      for (final c in state.dimensions.coordinates) {
        if (!state.isGiven(c) && state.currentGrid[c.row][c.col] == 0) {
          target = c;
          value = state.solutionGrid[c.row][c.col];
          break;
        }
      }
    }

    if (target == null) return null;

    state.currentGrid[target.row][target.col] = value!;
    state.notesAt(target).clear();
    state.hintsUsed++;
    state.selected = target;
    _errorCells = {};
    notifyListeners();
    await save(SaveTriggerType.hintUsed);
    await _checkWin();
    return target;
  }

  Future<void> _checkWin() async {
    if (state.completed) return;
    if (rules.isWin(state.currentGrid, state.solutionGrid)) {
      _foldElapsedIntoState();
      state.completed = true;
      state.actualSolveTime = state.elapsedTime;
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      await save(SaveTriggerType.levelComplete);
      await analytics.log('level_complete', {
        'level_id': state.levelId,
        'mistakes': state.mistakesCount,
        'hints': state.hintsUsed,
        'elapsed_ms': state.elapsedTime.inMilliseconds,
      });
    }
  }

  /// Persists a complete snapshot with the given [trigger].
  Future<void> save(SaveTriggerType trigger) async {
    _foldElapsedIntoState();
    final now = DateTime.now();
    final snapshot = state.toSnapshot(savedAt: now);
    state.lastSavedAt = now;
    await saveService.save(snapshot, trigger);
    await analytics.log('save', {
      'level_id': state.levelId,
      'trigger': trigger.wireName,
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// True when two given-cell grids are identical (same puzzle identity).
bool _sameGrid(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var r = 0; r < a.length; r++) {
    if (a[r].length != b[r].length) return false;
    for (var c = 0; c < a[r].length; c++) {
      if (a[r][c] != b[r][c]) return false;
    }
  }
  return true;
}
