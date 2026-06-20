import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_state.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/solver_step.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/solving_technique.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const solution = [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ];
  // Two blanks: (3,2) and (3,3).
  const puzzle = ManualPuzzle(
    levelId: 'hint_test',
    seed: 0,
    gridSize: GridDimensions(rows: 4, cols: 4),
    boxShape: BoxShape(rows: 2, cols: 2),
    solutionGrid: solution,
    givenCells: [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 0, 0],
    ],
    difficultyLabel: 'Quick',
    estimatedSolveTime: Duration(minutes: 1),
  );

  // Solver order: fill (3,2)=2 then (3,3)=1.
  final steps = [
    const SolverStep(
        cell: GridCoordinate(3, 2),
        technique: SolvingTechnique.nakedSingle,
        value: 2),
    const SolverStep(
        cell: GridCoordinate(3, 3),
        technique: SolvingTechnique.nakedSingle,
        value: 1),
  ];

  RunicSudokuController controller({List<SolverStep>? withSteps}) {
    return RunicSudokuController(
      state: RunicSudokuState.fromPuzzle(puzzle),
      saveService: LocalSaveRepository(),
      analytics: const NoopAnalyticsService(echoToConsole: false),
      solverSteps: withSteps ?? steps,
    );
  }

  test('reveals the next step from the solver log, in order', () async {
    final c = controller();

    final first = await c.revealNextHint();
    expect(first, const GridCoordinate(3, 2));
    expect(c.state.currentGrid[3][2], 2);
    expect(c.hintsUsed, 1);

    final second = await c.revealNextHint();
    expect(second, const GridCoordinate(3, 3));
    expect(c.state.currentGrid[3][3], 1);
  });

  test('skips a step the player already filled correctly', () async {
    final c = controller();
    c.state.currentGrid[3][2] = 2; // player already solved the first step

    final revealed = await c.revealNextHint();
    expect(revealed, const GridCoordinate(3, 3)); // not (3,2)
  });

  test('corrects a wrong value at the next step cell', () async {
    final c = controller();
    c.state.currentGrid[3][2] = 4; // wrong value at the first step's cell

    final revealed = await c.revealNextHint();
    expect(revealed, const GridCoordinate(3, 2));
    expect(c.state.currentGrid[3][2], 2); // corrected to the solution value
  });

  test('fallback reveals a correct empty cell when the log is empty', () async {
    final c = controller(withSteps: const []);
    final revealed = await c.revealNextHint();
    expect(revealed, isNotNull);
    expect(
      c.state.currentGrid[revealed!.row][revealed.col],
      solution[revealed.row][revealed.col],
    );
  });
}
