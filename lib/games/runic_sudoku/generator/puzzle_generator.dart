import 'dart:math';

import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';
import '../board_config.dart';
import '../solver/difficulty_constants.dart';
import '../solver/fast_uniqueness_solver.dart';
import '../solver/human_like_solver.dart';
import 'difficulty_scorer.dart';
import 'free_play_guardrails.dart';
import 'full_grid_generator.dart';
import 'level_data.dart';

/// Outcome of a generation run.
class GenerationResult {
  final LevelData level;
  final HumanLikeResult metrics;
  final int attempts;
  final int seedUsed;

  const GenerationResult({
    required this.level,
    required this.metrics,
    required this.attempts,
    required this.seedUsed,
  });
}

/// Generates puzzles for a target difficulty label using the complexity-based
/// model (Phase 0 §5 pipeline, re-expressed on `candidate_complexity`).
///
/// Strategy: from a full grid, greedily remove clues (random order, keeping the
/// puzzle uniquely solvable and MVP-solvable) and stop when the puzzle's
/// `candidate_complexity` lands in the target label's band. Because complexity
/// rises as clues are removed, one full grid usually yields the band directly, so
/// Quick/Normal/Tricky succeed in ~1 attempt. Deep IS reachable on 6×6 but only
/// at near-minimal puzzles (complexity >= 0.30), so it needs far more attempts
/// (measured ~30–65); pass a higher [maxAttempts] for Deep — the MVP
/// pre-generates Deep offline instead (see tool/generate_level_pool.dart). If the
/// band is not reached within [maxAttempts], this throws.
///
/// Parametric over the board via a REQUIRED [BoardConfig] — there is no
/// implicit default board, so every call site is an explicit, compiler-checked
/// decision (chapter-system refactor, Batch 2). Pure Dart.
class PuzzleGenerator {
  final BoardConfig board;
  final GridDimensions dimensions;
  final BoxShape boxShape;

  final FullGridGenerator _full;
  final FastUniquenessSolver _uniqueness;
  final HumanLikeSolver _human;
  final DifficultyScorer _scorer;

  PuzzleGenerator({required this.board})
      : dimensions = board.dimensions,
        boxShape = board.boxShape,
        _full = FullGridGenerator(
            dimensions: board.dimensions, boxShape: board.boxShape),
        _uniqueness = FastUniquenessSolver(
            dimensions: board.dimensions, boxShape: board.boxShape),
        _human = HumanLikeSolver(
            dimensions: board.dimensions, boxShape: board.boxShape),
        _scorer = const DifficultyScorer() {
    board.debugAssertValid();
  }

  /// Generates a puzzle whose candidate_complexity falls in [target]'s band.
  ///
  /// When [freePlay] is true, the carve additionally enforces
  /// [FreePlayGuardrails] (no/limited empty rows/cols/boxes, a guaranteed naked
  /// single from the start) so on-demand puzzles start cleanly. This flag is OFF
  /// by default, so the pre-generated campaign pool is unaffected.
  GenerationResult generate({
    required DifficultyLabel target,
    int? seed,
    int maxAttempts = 200,
    bool freePlay = false,
  }) {
    final baseSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final (lo, hi) = _scorer.complexityBand(target);

    // Free Play: require each candidate to also satisfy the guardrails. Applied
    // inside the carve so we keep the deepest in-band puzzle that PASSES, rather
    // than rejecting the whole attempt — this keeps rejection rates low.
    final bool Function(List<List<int>>)? accept = freePlay
        ? (g) => FreePlayGuardrails.passes(g, target, dimensions, boxShape)
        : null;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final attemptSeed = baseSeed + attempt;
      final rng = Random(attemptSeed);
      final full = _full.generate(rng);

      final carved = _carveToBand(full, rng, lo, hi, accept: accept);
      if (carved == null) continue;

      return GenerationResult(
        level: LevelData(
          gridSize: dimensions,
          boxShape: boxShape,
          solutionGrid: full,
          givenCells: carved.$1,
          difficultyLabel: target.token,
          estimatedSolveTime: carved.$2.estimatedSolveTime,
          seed: attemptSeed,
        ),
        metrics: carved.$2,
        attempts: attempt + 1,
        seedUsed: attemptSeed,
      );
    }

    throw StateError(
      'Failed to generate a ${target.token} puzzle within $maxAttempts '
      'attempts on a ${dimensions.toToken()} board '
      '(box ${boxShape.toToken()}). Deep lives at near-minimal puzzles '
      '(complexity >= ${DifficultyTuning.complexityTrickyMax}) and can need '
      'far more attempts than the other labels — raise maxAttempts or '
      'pre-generate offline (see tool/generate_level_pool.dart).',
    );
  }

  /// Greedily removes clues from [full] keeping uniqueness + MVP-solvability,
  /// returning the most-carved puzzle whose complexity is in `[lo, hi)`, or null
  /// if the band could not be reached on this grid.
  (List<List<int>>, HumanLikeResult)? _carveToBand(
    List<List<int>> full,
    Random rng,
    double lo,
    double hi, {
    bool Function(List<List<int>>)? accept,
  }) {
    final puzzle = [for (final row in full) List<int>.from(row)];
    final order = [
      for (var r = 0; r < dimensions.rows; r++)
        for (var c = 0; c < dimensions.cols; c++) GridCoordinate(r, c),
    ]..shuffle(rng);

    (List<List<int>>, HumanLikeResult)? best;

    for (final coord in order) {
      final saved = puzzle[coord.row][coord.col];
      if (saved == 0) continue;

      puzzle[coord.row][coord.col] = 0;

      if (_uniqueness.countSolutions(puzzle, maxSolutions: 2) != 1) {
        puzzle[coord.row][coord.col] = saved; // must stay unique
        continue;
      }
      final metrics = _human.analyze(puzzle, full);
      if (metrics.unsupportedTechnique ||
          metrics.candidateComplexity >= hi) {
        puzzle[coord.row][coord.col] = saved; // overshoot or unsolvable: keep clue
        continue;
      }
      // Accepted removal (unique, solvable, complexity < hi). For Free Play also
      // require the guardrails to pass before recording this as the best so far.
      if (metrics.candidateComplexity >= lo &&
          (accept == null || accept(puzzle))) {
        best = ([for (final row in puzzle) List<int>.from(row)], metrics);
      }
    }
    return best;
  }
}
