import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';

const _analytics = NoopAnalyticsService(echoToConsole: false);

Future<RunicSudokuController> _controller() =>
    RunicSudokuController.loadOrCreate(
      puzzle: notesTestPuzzle, // givens + ~20 blanks
      saveService: LocalSaveRepository(),
      analytics: _analytics,
      fresh: true,
    );

void main() {
  test('resetBoard clears player work but keeps givens and counters', () async {
    final c = await _controller();
    expect(c.hasPlayerProgress, isFalse);

    // Player work: a wrong value (bumps mistakes), a note, a check, a hint.
    c.selectCell(const GridCoordinate(0, 1)); // empty in notesTestPuzzle
    await c.inputValue(3); // wrong → mistakesCount++
    c.toggleNotesMode();
    c.selectCell(const GridCoordinate(0, 2));
    await c.inputValue(4); // a pencil note
    c.toggleNotesMode();
    await c.checkMistakes(); // checksUsed++
    await c.revealNextHint(); // hintsUsed++ (fills a cell)

    expect(c.hasPlayerProgress, isTrue);
    final mistakes = c.mistakesCount;
    final checks = c.checksUsed;
    final hints = c.hintsUsed;
    expect(mistakes, greaterThanOrEqualTo(1));
    expect(checks, 1);
    expect(hints, 1);

    await c.resetBoard();

    // Player solution + notes wiped...
    expect(c.hasPlayerProgress, isFalse);
    for (final coord in c.state.dimensions.coordinates) {
      if (!c.state.isGiven(coord)) {
        expect(c.state.currentGrid[coord.row][coord.col], 0);
      }
      expect(c.state.notesAt(coord), isEmpty);
    }
    // ...givens preserved...
    expect(c.state.currentGrid[0][0], notesTestPuzzle.givenCells[0][0]);
    // ...counters and completion untouched.
    expect(c.mistakesCount, mistakes);
    expect(c.checksUsed, checks);
    expect(c.hintsUsed, hints);
    expect(c.completed, isFalse);
  });

  test('resetBoard is a no-op once the puzzle is completed', () async {
    final c = await _controller();
    // Drive to completion by revealing every step.
    while (!c.completed) {
      final revealed = await c.revealNextHint();
      if (revealed == null) break;
    }
    expect(c.completed, isTrue);

    final grid = [
      for (final r in c.state.currentGrid) [...r],
    ];
    await c.resetBoard(); // must do nothing on a solved board
    expect(c.state.currentGrid, grid);
    expect(c.completed, isTrue);
  });
}
