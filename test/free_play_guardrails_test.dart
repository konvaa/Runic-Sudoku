import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/free_play_guardrails.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

const _dims = GridDimensions(rows: 6, cols: 6);
const _box = BoxShape(rows: 2, cols: 3);

/// A complete, valid 6×6 solution to mutate in the structural tests.
List<List<int>> _full() =>
    [for (final row in quickTestPuzzle.solutionGrid) List<int>.from(row)];

int _emptyRows(List<List<int>> g) {
  var n = 0;
  for (var r = 0; r < 6; r++) {
    if (List.generate(6, (c) => g[r][c]).every((v) => v == 0)) n++;
  }
  return n;
}

int _emptyCols(List<List<int>> g) {
  var n = 0;
  for (var c = 0; c < 6; c++) {
    var empty = true;
    for (var r = 0; r < 6; r++) {
      if (g[r][c] != 0) empty = false;
    }
    if (empty) n++;
  }
  return n;
}

bool _hasEmptyBox(List<List<int>> g) {
  for (var b = 0; b < _box.boxCount(_dims); b++) {
    if (_box.coordinatesInBox(b, _dims).every((c) => g[c.row][c.col] == 0)) {
      return true;
    }
  }
  return false;
}

void main() {
  group('FreePlayGuardrails (constructed grids)', () {
    test('near-complete grid with no empty row/col passes Quick & Normal', () {
      final g = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.quick, _dims, _box),
          isTrue);
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.normal, _dims, _box),
          isTrue);
    });

    test('Quick/Normal reject any fully-empty row or column', () {
      final rowEmpty = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      for (var c = 0; c < 6; c++) {
        rowEmpty[0][c] = 0; // wipe row 0
      }
      expect(
          FreePlayGuardrails.passes(rowEmpty, DifficultyLabel.quick, _dims, _box),
          isFalse);

      final colEmpty = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      for (var r = 0; r < 6; r++) {
        colEmpty[r][0] = 0; // wipe col 0
      }
      expect(
          FreePlayGuardrails.passes(
              colEmpty, DifficultyLabel.normal, _dims, _box),
          isFalse);
    });

    test('Tricky/Deep allow one empty line but reject two', () {
      // One empty row only (+ the 4 existing blanks) — allowed for hard labels.
      final one = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      for (var c = 0; c < 6; c++) {
        one[0][c] = 0;
      }
      expect(_emptyRows(one) + _emptyCols(one), 1);
      expect(FreePlayGuardrails.passes(one, DifficultyLabel.tricky, _dims, _box),
          isTrue);
      // ...but Quick still rejects the empty row.
      expect(FreePlayGuardrails.passes(one, DifficultyLabel.quick, _dims, _box),
          isFalse);

      // One empty row AND one empty column = two empty lines — rejected.
      final two = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      for (var c = 0; c < 6; c++) {
        two[0][c] = 0;
      }
      for (var r = 0; r < 6; r++) {
        two[r][0] = 0;
      }
      expect(_emptyRows(two) + _emptyCols(two), 2);
      expect(FreePlayGuardrails.passes(two, DifficultyLabel.deep, _dims, _box),
          isFalse);
    });

    test('Tricky/Deep reject a fully-empty 2x3 box', () {
      final g = quickTestPuzzle.givenCells.map((r) => [...r]).toList();
      // Wipe box 0 (rows 0-1, cols 0-2).
      for (final coord in _box.coordinatesInBox(0, _dims)) {
        g[coord.row][coord.col] = 0;
      }
      expect(_hasEmptyBox(g), isTrue);
      expect(_emptyRows(g) + _emptyCols(g), 0); // box-only, no empty line
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.tricky, _dims, _box),
          isFalse);
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.deep, _dims, _box),
          isFalse);
    });

    test('rejects a board with no naked single (deadly rectangle)', () {
      // Blanking the 1/4 swap rectangle at (0,0),(0,3),(1,0),(1,3) leaves each
      // empty cell with two candidates {1,4} — no immediate first move.
      final g = _full();
      g[0][0] = 0;
      g[0][3] = 0;
      g[1][0] = 0;
      g[1][3] = 0;
      expect(_emptyRows(g) + _emptyCols(g), 0);
      expect(_hasEmptyBox(g), isFalse);
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.quick, _dims, _box),
          isFalse);
      expect(FreePlayGuardrails.passes(g, DifficultyLabel.tricky, _dims, _box),
          isFalse);
    });
  });

  group('Free Play generation honors the guardrails', () {
    final generator = PuzzleGenerator();

    void check(DifficultyLabel label, int count, int maxAttempts) {
      for (var i = 0; i < count; i++) {
        final r = generator.generate(
          target: label,
          seed: 7000 + i * 911 + label.index,
          maxAttempts: maxAttempts,
          freePlay: true,
        );
        final g = r.level.givenCells;
        expect(FreePlayGuardrails.passes(g, label, _dims, _box), isTrue,
            reason: '${label.token} #$i must pass guardrails');
        final hard =
            label == DifficultyLabel.tricky || label == DifficultyLabel.deep;
        if (hard) {
          expect(_emptyRows(g) + _emptyCols(g), lessThanOrEqualTo(1));
          expect(_hasEmptyBox(g), isFalse);
        } else {
          expect(_emptyRows(g), 0);
          expect(_emptyCols(g), 0);
        }
      }
    }

    test('Quick puzzles have no empty row/col', () => check(DifficultyLabel.quick, 4, 200));
    test('Normal puzzles have no empty row/col', () => check(DifficultyLabel.normal, 4, 200));
    test('Tricky puzzles respect the hard guardrails', () => check(DifficultyLabel.tricky, 4, 400));
    test('Deep puzzles respect the hard guardrails', () => check(DifficultyLabel.deep, 2, 1500),
        timeout: const Timeout(Duration(minutes: 2)));
  });
}
