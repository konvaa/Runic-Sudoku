import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/difficulty_scorer.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/full_grid_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/level_data.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_rules.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/fast_uniqueness_solver.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/human_like_solver.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/solver_step.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const dims = GridDimensions(rows: 6, cols: 6);
  const box = BoxShape(rows: 2, cols: 3);
  const rules = RunicSudokuRules.sixBySix;
  const scorer = DifficultyScorer();

  group('full grid generation', () {
    test('produces a complete grid satisfying all constraints', () {
      final gen = FullGridGenerator(dimensions: dims, boxShape: box);
      for (final seed in [1, 2, 3, 99]) {
        final grid = gen.generate(Random(seed));
        expect(rules.isFilled(grid), isTrue, reason: 'seed $seed filled');
        expect(rules.isCompleteAndValid(grid), isTrue,
            reason: 'seed $seed valid');
      }
    });
  });

  group('puzzle generation (complexity-based model)', () {
    final generator = PuzzleGenerator(board: BoardConfig.sixBySix);
    final uniqueness =
        FastUniquenessSolver(dimensions: dims, boxShape: box);

    // The three 6x6-reachable labels: each must be uniquely solvable and its
    // candidate_complexity must classify back to the requested label.
    for (final entry in {
      DifficultyLabel.quick: 'Quick',
      DifficultyLabel.normal: 'Normal',
      DifficultyLabel.tricky: 'Tricky',
    }.entries) {
      test('${entry.value} puzzle is unique and classifies as ${entry.value}',
          () {
        final r =
            generator.generate(target: entry.key, seed: 4242, maxAttempts: 400);
        expect(r.level.difficultyLabel, entry.value);
        expect(uniqueness.countSolutions(r.level.givenCells), 1);
        expect(scorer.classify(r.metrics), entry.key);
        expect(rules.isCompleteAndValid(r.level.solutionGrid), isTrue);
      });
    }

    test('estimated solve time is ordered Quick < Normal < Tricky', () {
      final q = generator
          .generate(target: DifficultyLabel.quick, seed: 11, maxAttempts: 400)
          .metrics
          .estimatedSolveTime;
      final n = generator
          .generate(target: DifficultyLabel.normal, seed: 11, maxAttempts: 400)
          .metrics
          .estimatedSolveTime;
      final t = generator
          .generate(target: DifficultyLabel.tricky, seed: 11, maxAttempts: 400)
          .metrics
          .estimatedSolveTime;
      expect(q < n, isTrue, reason: 'Quick($q) should be < Normal($n)');
      expect(n < t, isTrue, reason: 'Normal($n) should be < Tricky($t)');
    });

    test('Deep is generatable on 6x6 with a high attempt budget (costly)', () {
      // Deep lives at near-minimal puzzles (complexity >= 0.30) and needs many
      // more attempts than the others (~30-65), which is why the MVP
      // pre-generates it offline. With a generous budget it generates reliably.
      final r = generator.generate(
          target: DifficultyLabel.deep, seed: 4242, maxAttempts: 600);
      expect(r.level.difficultyLabel, 'Deep');
      expect(scorer.classify(r.metrics), DifficultyLabel.deep);
      expect(uniqueness.countSolutions(r.level.givenCells), 1);
    });
  });

  group('level export / import', () {
    test('round-trips solution_grid and given_cells', () {
      final generator = PuzzleGenerator(board: BoardConfig.sixBySix);
      final result = generator.generate(
          target: DifficultyLabel.normal, seed: 123, maxAttempts: 400);
      final restored = LevelData.fromJson(result.level.toJson());

      expect(restored.solutionGrid, result.level.solutionGrid);
      expect(restored.givenCells, result.level.givenCells);
      expect(restored.gridSize, dims);
      expect(restored.boxShape, box);
      expect(restored.difficultyLabel, 'Normal');
    });
  });

  group('classification & rejection rules (complexity-based)', () {
    HumanLikeResult metrics({
      required double complexity,
      bool unsupported = false,
    }) {
      return HumanLikeResult(
        forcedMovesCount: 10,
        decisionPointsCount: 0, // secondary metric, ignored by the model
        candidateComplexity: complexity,
        maxCandidates: 4,
        estimatedSolveTime: const Duration(seconds: 90),
        difficultyScore: complexity,
        unsupportedTechnique: unsupported,
        solverStepsLog: const <SolverStep>[],
        solved: !unsupported,
      );
    }

    test('classify maps complexity to the right label', () {
      expect(scorer.classify(metrics(complexity: 0.00)), DifficultyLabel.quick);
      expect(scorer.classify(metrics(complexity: 0.05)), DifficultyLabel.normal);
      expect(scorer.classify(metrics(complexity: 0.15)), DifficultyLabel.tricky);
      expect(scorer.classify(metrics(complexity: 0.40)), DifficultyLabel.deep);
    });

    test('unsupported puzzle has no label and is rejected for any target', () {
      final r = metrics(complexity: 0.05, unsupported: true);
      expect(scorer.classify(r), isNull);
      expect(scorer.isRejectedForTarget(r, DifficultyLabel.normal), isTrue);
    });

    test('a Quick-complexity puzzle is rejected when Normal was requested', () {
      final r = metrics(complexity: 0.01);
      expect(scorer.isRejectedForTarget(r, DifficultyLabel.normal), isTrue);
      expect(scorer.isRejectedForTarget(r, DifficultyLabel.quick), isFalse);
    });
  });
}
