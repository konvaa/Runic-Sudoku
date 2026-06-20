import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';
import 'difficulty_constants.dart';
import 'solver_step.dart';
import 'solving_technique.dart';

/// Metrics produced by the Human-Like Solver (Phase 0 §3.1 / §4.2).
///
/// `difficultyLabel` is intentionally NOT part of this result — label assignment
/// is policy that lives in `DifficultyScorer`, and per spec it must NOT be
/// assigned when [unsupportedTechnique] is true.
class HumanLikeResult {
  final int forcedMovesCount;

  /// Secondary metric only. As of the complexity-based model it is NOT used for
  /// label assignment or rejection on 6×6 (stalls are effectively non-existent
  /// there); it is retained for future larger grids. See PHASE2_NOTES.md.
  final int decisionPointsCount;

  /// PRIMARY difficulty signal (Phase 0 §3.1), measured on the initial givens.
  final double candidateComplexity; // 0.0 .. 1.0

  /// Peak candidate-set size on the initial givens. Secondary signal, kept for
  /// diagnostics / future tuning (not used for labels in the current model).
  final int maxCandidates;

  final Duration estimatedSolveTime;
  final double difficultyScore;
  final bool unsupportedTechnique;
  final List<SolverStep> solverStepsLog;

  /// True when the solver reached a complete grid (possibly via decision points).
  final bool solved;

  const HumanLikeResult({
    required this.forcedMovesCount,
    required this.decisionPointsCount,
    required this.candidateComplexity,
    required this.maxCandidates,
    required this.estimatedSolveTime,
    required this.difficultyScore,
    required this.unsupportedTechnique,
    required this.solverStepsLog,
    required this.solved,
  });

  Map<String, dynamic> toJson() => {
        'difficulty_score': difficultyScore,
        'decision_points_count': decisionPointsCount,
        'forced_moves_count': forcedMovesCount,
        'candidate_complexity': candidateComplexity,
        'max_candidates': maxCandidates,
        'estimated_solve_time': estimatedSolveTime.inMilliseconds,
        'unsupported_technique': unsupportedTechnique,
        'solver_steps_log': [for (final s in solverStepsLog) s.toJson()],
      };
}

/// Human-like difficulty solver. Runs ONCE per puzzle (not speed-critical).
///
/// Method (Phase 0 §4.2): candidate generation (row/column/box elimination) as a
/// continuous step, then the MVP techniques in order — naked single, then hidden
/// single — repeated until the puzzle is solved or the techniques stall.
///
/// DECISION-POINT MODEL (see PHASE2_NOTES.md for the full rationale and the
/// Phase 2 change history): a **decision point** is a *stall* — a step where
/// neither a naked nor a hidden single is available and the puzzle is unsolved —
/// occurring while the board is still complex (more than
/// `DifficultyTuning.decisionPointCellThreshold` empty cells have ≥2 candidates).
/// To get past a stall without building a backtracking solver (explicitly out of
/// scope), the solver commits the **known solution value** at the
/// minimum-remaining-values cell, counts a decision point, and continues. This
/// makes `decision_points_count` the number of non-deducible steps on the path
/// to the solution — small integers that match the Phase 0 label ranges
/// (Quick 0, Normal 1–2, Tricky 2–4, Deep 4+).
///
/// `unsupported_technique` is set when the techniques stall in a state that is
/// NOT a legitimate decision point: a contradiction (an empty cell with zero
/// candidates), a too-tight stall (≤ N complex cells, i.e. a local pattern the
/// MVP cannot resolve), or givens inconsistent with the supplied solution. No
/// difficulty label may be assigned in that case.
///
/// Parametric over grid size / box shape; requires the puzzle's [solutionGrid].
class HumanLikeSolver {
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final int _n;

  HumanLikeSolver({required this.dimensions, required this.boxShape})
      : _n = dimensions.cols;

  /// Analyzes [givenCells] (0 = empty) against its full [solutionGrid].
  HumanLikeResult analyze(
    List<List<int>> givenCells,
    List<List<int>> solutionGrid,
  ) {
    final board = [for (final row in givenCells) List<int>.from(row)];
    final steps = <SolverStep>[];
    var forced = 0;
    var decisions = 0;

    // candidate_complexity (primary signal) and max candidates are measured on
    // the INITIAL puzzle state.
    final initialCandidates = _allCandidates(board);
    final complexity = _candidateComplexity(initialCandidates);
    final maxCandidates = _maxCandidates(initialCandidates);

    var unsupported = false;

    while (!_isFilled(board)) {
      final candidates = _allCandidates(board);

      // Contradiction: an empty cell with no candidate.
      if (candidates.values.any((s) => s.isEmpty)) {
        unsupported = true;
        break;
      }

      // 1) Naked single.
      final naked = _findNakedSingle(candidates);
      if (naked != null) {
        board[naked.$1.row][naked.$1.col] = naked.$2;
        forced++;
        steps.add(SolverStep(
          cell: naked.$1,
          technique: SolvingTechnique.nakedSingle,
          value: naked.$2,
        ));
        continue;
      }

      // 2) Hidden single.
      final hidden = _findHiddenSingle(candidates);
      if (hidden != null) {
        board[hidden.$1.row][hidden.$1.col] = hidden.$2;
        forced++;
        steps.add(SolverStep(
          cell: hidden.$1,
          technique: SolvingTechnique.hiddenSingle,
          value: hidden.$2,
        ));
        continue;
      }

      // Stall: MVP techniques exhausted and not solved.
      final complexCells =
          candidates.values.where((s) => s.length >= 2).length;
      if (complexCells <= DifficultyTuning.decisionPointCellThreshold) {
        // Too tight to be a legitimate decision point -> needs a real technique.
        unsupported = true;
        break;
      }

      // Legitimate decision point: commit the known solution value at the MRV
      // cell and continue. (We do NOT search/backtrack — that would be a general
      // solver, which is out of scope.)
      final mrv = _mrvCell(candidates);
      final solutionValue = solutionGrid[mrv.row][mrv.col];
      if (!candidates[mrv]!.contains(solutionValue)) {
        // Givens inconsistent with the supplied solution.
        unsupported = true;
        break;
      }
      board[mrv.row][mrv.col] = solutionValue;
      decisions++;
      steps.add(SolverStep(
        cell: mrv,
        technique: SolvingTechnique.decisionPoint,
        value: solutionValue,
      ));
    }

    final solved = _isFilled(board) && !unsupported;

    // estimated_solve_time is driven by candidate_complexity, NOT by the number
    // of forced moves (= blank count), so difficulty — not emptiness — sets the
    // estimate. difficulty_score is just the primary signal itself.
    final estSeconds = DifficultyTuning.estBaseSeconds +
        complexity * DifficultyTuning.estComplexityScaleSeconds;
    final score = complexity;

    return HumanLikeResult(
      forcedMovesCount: forced,
      decisionPointsCount: decisions,
      candidateComplexity: complexity,
      maxCandidates: maxCandidates,
      estimatedSolveTime: Duration(milliseconds: (estSeconds * 1000).round()),
      difficultyScore: score,
      unsupportedTechnique: unsupported,
      solverStepsLog: steps,
      solved: solved,
    );
  }

  /// Peak candidate-set size among empty cells (0 if the board is full).
  int _maxCandidates(Map<GridCoordinate, Set<int>> candidates) {
    var maxCount = 0;
    for (final s in candidates.values) {
      if (s.length > maxCount) maxCount = s.length;
    }
    return maxCount;
  }

  // ---- Techniques ----------------------------------------------------------

  (GridCoordinate, int)? _findNakedSingle(
    Map<GridCoordinate, Set<int>> candidates,
  ) {
    for (final entry in candidates.entries) {
      if (entry.value.length == 1) return (entry.key, entry.value.first);
    }
    return null;
  }

  (GridCoordinate, int)? _findHiddenSingle(
    Map<GridCoordinate, Set<int>> candidates,
  ) {
    for (var r = 0; r < dimensions.rows; r++) {
      final hit = _hiddenSingleInUnit(
        [for (var c = 0; c < dimensions.cols; c++) GridCoordinate(r, c)],
        candidates,
      );
      if (hit != null) return hit;
    }
    for (var c = 0; c < dimensions.cols; c++) {
      final hit = _hiddenSingleInUnit(
        [for (var r = 0; r < dimensions.rows; r++) GridCoordinate(r, c)],
        candidates,
      );
      if (hit != null) return hit;
    }
    for (var b = 0; b < boxShape.boxCount(dimensions); b++) {
      final hit = _hiddenSingleInUnit(
        boxShape.coordinatesInBox(b, dimensions),
        candidates,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  (GridCoordinate, int)? _hiddenSingleInUnit(
    List<GridCoordinate> unit,
    Map<GridCoordinate, Set<int>> candidates,
  ) {
    for (var v = 1; v <= _n; v++) {
      GridCoordinate? home;
      var count = 0;
      for (final coord in unit) {
        final cand = candidates[coord];
        if (cand != null && cand.contains(v)) {
          count++;
          home = coord;
          if (count > 1) break;
        }
      }
      if (count == 1) return (home!, v);
    }
    return null;
  }

  /// Empty cell with the fewest candidates (row-major tiebreak).
  GridCoordinate _mrvCell(Map<GridCoordinate, Set<int>> candidates) {
    GridCoordinate? best;
    var bestCount = _n + 1;
    for (final entry in candidates.entries) {
      if (entry.value.length < bestCount) {
        bestCount = entry.value.length;
        best = entry.key;
      }
    }
    return best!;
  }

  // ---- Candidate generation ------------------------------------------------

  Map<GridCoordinate, Set<int>> _allCandidates(List<List<int>> board) {
    final rowUsed = List<Set<int>>.generate(dimensions.rows, (r) {
      final s = <int>{};
      for (var c = 0; c < dimensions.cols; c++) {
        if (board[r][c] != 0) s.add(board[r][c]);
      }
      return s;
    });
    final colUsed = List<Set<int>>.generate(dimensions.cols, (c) {
      final s = <int>{};
      for (var r = 0; r < dimensions.rows; r++) {
        if (board[r][c] != 0) s.add(board[r][c]);
      }
      return s;
    });
    final boxUsed = List<Set<int>>.generate(boxShape.boxCount(dimensions), (b) {
      final s = <int>{};
      for (final coord in boxShape.coordinatesInBox(b, dimensions)) {
        final v = board[coord.row][coord.col];
        if (v != 0) s.add(v);
      }
      return s;
    });

    final result = <GridCoordinate, Set<int>>{};
    for (var r = 0; r < dimensions.rows; r++) {
      for (var c = 0; c < dimensions.cols; c++) {
        if (board[r][c] != 0) continue;
        final coord = GridCoordinate(r, c);
        final b = boxShape.boxIndexFor(coord, dimensions);
        final cand = <int>{};
        for (var v = 1; v <= _n; v++) {
          if (!rowUsed[r].contains(v) &&
              !colUsed[c].contains(v) &&
              !boxUsed[b].contains(v)) {
            cand.add(v);
          }
        }
        result[coord] = cand;
      }
    }
    return result;
  }

  // ---- Metrics helpers -----------------------------------------------------

  /// candidate_complexity per Phase 0 §3.1:
  /// (Σ max(0, |candidates(cell)| - 2)) / (empty_cell_count * (grid_size - 2)),
  /// clamped to [0, 1]. Returns 0 when there are no empty cells.
  double _candidateComplexity(Map<GridCoordinate, Set<int>> candidates) {
    final emptyCount = candidates.length;
    final denom = emptyCount * (_n - 2);
    if (denom <= 0) return 0;
    var sum = 0;
    for (final cand in candidates.values) {
      final excess = cand.length - 2;
      if (excess > 0) sum += excess;
    }
    final value = sum / denom;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  bool _isFilled(List<List<int>> board) {
    for (var r = 0; r < dimensions.rows; r++) {
      for (var c = 0; c < dimensions.cols; c++) {
        if (board[r][c] == 0) return false;
      }
    }
    return true;
  }
}
