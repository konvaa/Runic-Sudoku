import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/difficulty_scorer.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/human_like_solver.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/solving_technique.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  // Tests use a 4x4 / 2x2 grid: small enough to hand-trace fully, and it also
  // exercises the solver's parametricity (nothing is hardcoded to 6x6).
  const dims = GridDimensions(rows: 4, cols: 4);
  const box = BoxShape(rows: 2, cols: 2);
  HumanLikeSolver solver() =>
      HumanLikeSolver(dimensions: dims, boxShape: box);

  const solution4 = [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ];

  group('trivial puzzle (naked singles only)', () {
    final puzzle = [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 0, 0],
    ];

    test('forced moves > 0, no decision points, not unsupported', () {
      final r = solver().analyze(puzzle, solution4);
      expect(r.forcedMovesCount, 2);
      expect(r.decisionPointsCount, 0);
      expect(r.unsupportedTechnique, isFalse);
      expect(r.solved, isTrue);
      expect(r.candidateComplexity, 0);
      expect(r.maxCandidates, 1); // both blanks are forced (one candidate each)
    });
  });

  group('puzzle requiring a decision point', () {
    // A "deadly rectangle": the four blanks each have candidates {1,2}, so no
    // naked or hidden single exists -> the singles stall while 4 (> N=3) cells
    // are still complex -> one decision point, resolved against the solution.
    final puzzle = [
      [0, 0, 3, 4],
      [3, 4, 1, 2],
      [0, 0, 4, 3],
      [4, 3, 2, 1],
    ];

    test('decision_points_count > 0 and still solves', () {
      final r = solver().analyze(puzzle, solution4);
      expect(r.decisionPointsCount, greaterThan(0));
      expect(r.solved, isTrue);
      expect(r.unsupportedTechnique, isFalse);
    });
  });

  group('puzzle the MVP solver cannot finish', () {
    // (0,0) sees 2,3,4 in its row and 1 in its column/box -> zero candidates: a
    // contradiction the MVP techniques cannot resolve.
    final puzzle = [
      [0, 2, 3, 4],
      [1, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ];

    test('unsupported_technique == true and no label assigned', () {
      final r = solver().analyze(puzzle, solution4);
      expect(r.unsupportedTechnique, isTrue);
      expect(r.solved, isFalse);
      expect(const DifficultyScorer().classify(r), isNull);
    });
  });

  group('solver_steps_log fidelity', () {
    final puzzle = [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 0, 0],
    ];

    test('log length matches moves and replays to the solution', () {
      final r = solver().analyze(puzzle, solution4);
      // Trivial puzzle: every step is a deductive naked single (no decisions).
      expect(r.solverStepsLog.length, r.forcedMovesCount + r.decisionPointsCount);
      expect(
        r.solverStepsLog.every((s) => s.technique == SolvingTechnique.nakedSingle),
        isTrue,
      );

      final board = [for (final row in puzzle) List<int>.from(row)];
      for (final step in r.solverStepsLog) {
        expect(board[step.cell.row][step.cell.col], 0);
        board[step.cell.row][step.cell.col] = step.value;
      }
      expect(board, solution4);
    });
  });
}
