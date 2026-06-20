import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_state.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const puzzle = ManualPuzzle(
    levelId: 'check_test',
    seed: 0,
    gridSize: GridDimensions(rows: 4, cols: 4),
    boxShape: BoxShape(rows: 2, cols: 2),
    solutionGrid: [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 2, 1],
    ],
    givenCells: [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 0, 0],
    ],
    difficultyLabel: 'Quick',
    estimatedSolveTime: Duration(minutes: 1),
  );

  RunicSudokuController controller() => RunicSudokuController(
        state: RunicSudokuState.fromPuzzle(puzzle),
        saveService: LocalSaveRepository(),
        analytics: const NoopAnalyticsService(echoToConsole: false),
      );

  test('first check is free; subsequent checks are gated', () async {
    final c = controller();

    // The screen only requires a rewarded ad once the free check is spent.
    expect(c.hasFreeCheck, isTrue);
    expect(c.checksUsed, 0);

    await c.checkMistakes(); // the single free check
    expect(c.checksUsed, 1);
    expect(c.hasFreeCheck, isFalse); // -> screen now requires rewardGranted

    await c.checkMistakes(); // would only happen after a rewarded ad
    expect(c.checksUsed, 2);
  });
}
