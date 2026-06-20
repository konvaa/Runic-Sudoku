import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/fast_uniqueness_solver.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const dims = GridDimensions(rows: 6, cols: 6);
  const box = BoxShape(rows: 2, cols: 3);
  FastUniquenessSolver solver() =>
      FastUniquenessSolver(dimensions: dims, boxShape: box);

  // Unique puzzle: the four blanks are each forced (one candidate).
  final uniquePuzzle = [
    [1, 2, 3, 4, 5, 6],
    [4, 5, 6, 1, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 0, 0],
    [6, 4, 5, 3, 0, 0],
  ];

  // Deadly rectangle: the four blanks {1,4} can be filled two ways -> 2 solutions.
  final multiSolutionPuzzle = [
    [0, 2, 3, 0, 5, 6],
    [0, 5, 6, 0, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 4, 5],
    [6, 4, 5, 3, 1, 2],
  ];

  // Invalid givens: two 1s in row 0.
  final invalidPuzzle = [
    [1, 1, 3, 4, 5, 6],
    [4, 5, 6, 1, 2, 3],
    [2, 3, 1, 5, 6, 4],
    [5, 6, 4, 2, 3, 1],
    [3, 1, 2, 6, 4, 5],
    [6, 4, 5, 3, 1, 2],
  ];

  List<List<int>> emptyGrid() =>
      [for (var r = 0; r < 6; r++) List<int>.filled(6, 0)];

  test('unique puzzle returns 1', () {
    expect(solver().countSolutions(uniquePuzzle), 1);
  });

  test('multi-solution puzzle returns 2', () {
    expect(solver().countSolutions(multiSolutionPuzzle), 2);
  });

  test('invalid / unsatisfiable puzzle returns 0', () {
    expect(solver().countSolutions(invalidPuzzle), 0);
  });

  test('stops as soon as maxSolutions solutions are found', () {
    // The empty grid has astronomically many solutions; if the search did not
    // short-circuit at the cap it would never finish. Completion alone proves
    // the early stop; we also show the cap controls the result and the work.
    final s = solver();

    final two = s.countSolutions(emptyGrid(), maxSolutions: 2);
    final nodesForTwo = s.nodesVisited;
    expect(two, 2);

    final three = s.countSolutions(emptyGrid(), maxSolutions: 3);
    final nodesForThree = s.nodesVisited;
    expect(three, 3);

    // Finding one more solution cannot take fewer nodes than finding two.
    expect(nodesForThree, greaterThanOrEqualTo(nodesForTwo));
  });
}
