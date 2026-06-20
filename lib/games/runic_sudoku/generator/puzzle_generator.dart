import 'dart:math';

import '../../../grid/box_shape.dart';
import '../../../grid/grid_coordinate.dart';
import '../../../grid/grid_dimensions.dart';
import '../solver/difficulty_constants.dart';
import '../solver/fast_uniqueness_solver.dart';
import '../solver/human_like_solver.dart';
import 'difficulty_scorer.dart';
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
/// Parametric over grid size / box shape (defaults to 6×6 / 2×3). Pure Dart.
class PuzzleGenerator {
  final GridDimensions dimensions;
  final BoxShape boxShape;

  final FullGridGenerator _full;
  final FastUniquenessSolver _uniqueness;
  final HumanLikeSolver _human;
  final DifficultyScorer _scorer;

  PuzzleGenerator({
    this.dimensions = const GridDimensions(rows: 6, cols: 6),
    this.boxShape = const BoxShape(rows: 2, cols: 3),
  })  : _full =
            FullGridGenerator(dimensions: dimensions, boxShape: boxShape),
        _uniqueness =
            FastUniquenessSolver(dimensions: dimensions, boxShape: boxShape),
        _human =
            HumanLikeSolver(dimensions: dimensions, boxShape: boxShape),
        _scorer = const DifficultyScorer();

  /// Generates a puzzle whose candidate_complexity falls in [target]'s band.
  GenerationResult generate({
    required DifficultyLabel target,
    int? seed,
    int maxAttempts = 200,
  }) {
    final baseSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final (lo, hi) = _scorer.complexityBand(target);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final attemptSeed = baseSeed + attempt;
      final rng = Random(attemptSeed);
      final full = _full.generate(rng);

      final carved = _carveToBand(full, rng, lo, hi);
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
      'Failed to generate a ${target.token} puzzle within $maxAttempts attempts. '
      'Deep on 6×6 is reachable but costly (near-minimal puzzles, '
      'complexity >= ${DifficultyTuning.complexityTrickyMax}); it typically needs '
      '~30–65 attempts, so raise maxAttempts (the MVP pre-generates Deep offline). '
      'Quick/Normal/Tricky normally succeed in ~1 attempt.',
    );
  }

  /// Greedily removes clues from [full] keeping uniqueness + MVP-solvability,
  /// returning the most-carved puzzle whose complexity is in `[lo, hi)`, or null
  /// if the band could not be reached on this grid.
  (List<List<int>>, HumanLikeResult)? _carveToBand(
    List<List<int>> full,
    Random rng,
    double lo,
    double hi,
  ) {
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
      // Accepted removal (unique, solvable, complexity < hi).
      if (metrics.candidateComplexity >= lo) {
        best = ([for (final row in puzzle) List<int>.from(row)], metrics);
      }
    }
    return best;
  }
}
