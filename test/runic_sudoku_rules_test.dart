import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_rules.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';

void main() {
  const rules = RunicSudokuRules.sixBySix;

  // A valid 6x6 solution (rows, cols and 2x3 boxes each contain 1..6 once).
  final solution = [
    [1, 2, 3, 4, 5, 6],
    [4, 5, 6, 1, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 4, 5],
    [6, 4, 5, 3, 1, 2],
  ];

  List<List<int>> emptyGrid() =>
      [for (var r = 0; r < 6; r++) List<int>.filled(6, 0)];

  group('complete grid validation', () {
    test('a valid complete grid passes', () {
      expect(rules.isFilled(solution), isTrue);
      expect(rules.conflicts(solution), isEmpty);
      expect(rules.isCompleteAndValid(solution), isTrue);
    });
  });

  group('duplicate detection (isolated per unit)', () {
    test('duplicate in a row fails', () {
      final grid = emptyGrid();
      grid[0][0] = 1; // box 0, col 0
      grid[0][5] = 1; // same row, different col + box
      final conflicts = rules.conflicts(grid);
      expect(conflicts, contains(const GridCoordinate(0, 0)));
      expect(conflicts, contains(const GridCoordinate(0, 5)));
      expect(rules.isCompleteAndValid(grid), isFalse);
    });

    test('duplicate in a column fails', () {
      final grid = emptyGrid();
      grid[0][0] = 1; // box 0
      grid[5][0] = 1; // same col, different row + box
      final conflicts = rules.conflicts(grid);
      expect(conflicts, contains(const GridCoordinate(0, 0)));
      expect(conflicts, contains(const GridCoordinate(5, 0)));
    });

    test('duplicate in a box fails', () {
      final grid = emptyGrid();
      grid[0][0] = 1; // box 0
      grid[1][2] = 1; // same box (rows 0-1, cols 0-2), diff row + col
      final conflicts = rules.conflicts(grid);
      expect(conflicts, contains(const GridCoordinate(0, 0)));
      expect(conflicts, contains(const GridCoordinate(1, 2)));
    });
  });

  group('placement helpers', () {
    test('canPlace respects row/col/box constraints', () {
      final grid = emptyGrid();
      grid[0][0] = 1;
      expect(rules.canPlace(grid, const GridCoordinate(0, 3), 1), isFalse); // row
      expect(rules.canPlace(grid, const GridCoordinate(3, 0), 1), isFalse); // col
      expect(rules.canPlace(grid, const GridCoordinate(1, 1), 1), isFalse); // box
      expect(rules.canPlace(grid, const GridCoordinate(3, 3), 1), isTrue);
      expect(rules.canPlace(grid, const GridCoordinate(3, 3), 7), isFalse); // range
    });

    test('isCorrectPlacement compares against the solution', () {
      expect(
        rules.isCorrectPlacement(solution, const GridCoordinate(2, 2), 1),
        isTrue,
      );
      expect(
        rules.isCorrectPlacement(solution, const GridCoordinate(2, 2), 5),
        isFalse,
      );
    });

    test('mistakesAgainstSolution finds wrong non-empty cells', () {
      final grid = emptyGrid();
      grid[0][0] = 1; // correct
      grid[0][1] = 6; // wrong (solution is 2)
      final mistakes = rules.mistakesAgainstSolution(grid, solution);
      expect(mistakes, {const GridCoordinate(0, 1)});
    });
  });

  group('win condition', () {
    test('isWin true only when current equals solution', () {
      final current = [for (final row in solution) List<int>.from(row)];
      expect(rules.isWin(current, solution), isTrue);
      current[3][3] = 0;
      expect(rules.isWin(current, solution), isFalse);
    });
  });
}
