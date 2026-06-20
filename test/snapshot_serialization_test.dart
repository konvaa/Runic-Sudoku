import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_snapshot.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  RunicSudokuSnapshot sample() => RunicSudokuSnapshot(
        levelId: 'rs_quick_test',
        seed: 1001,
        gridSize: const GridDimensions(rows: 6, cols: 6),
        boxShape: const BoxShape(rows: 2, cols: 3),
        solutionGrid: const [
          [1, 2, 3, 4, 5, 6],
          [4, 5, 6, 1, 2, 3],
          [2, 3, 1, 5, 6, 4],
          [5, 6, 4, 2, 3, 1],
          [3, 1, 2, 6, 4, 5],
          [6, 4, 5, 3, 1, 2],
        ],
        givenCells: const [
          [1, 2, 3, 4, 5, 6],
          [4, 5, 6, 1, 2, 3],
          [2, 3, 1, 5, 6, 4],
          [5, 6, 4, 2, 3, 1],
          [3, 1, 2, 6, 0, 0],
          [6, 4, 5, 3, 0, 0],
        ],
        currentGrid: const [
          [1, 2, 3, 4, 5, 6],
          [4, 5, 6, 1, 2, 3],
          [2, 3, 1, 5, 6, 4],
          [5, 6, 4, 2, 3, 1],
          [3, 1, 2, 6, 4, 0],
          [6, 4, 5, 3, 0, 0],
        ],
        notesGrid: const [
          [[], [], [], [], [], []],
          [[], [], [], [], [], []],
          [[], [], [], [], [], []],
          [[], [], [], [], [], []],
          [[], [], [], [], [], [5]],
          [[], [], [], [], [1, 2], []],
        ],
        mistakesCount: 2,
        hintsUsed: 1,
        startedAt: DateTime.parse('2026-06-16T10:00:00.000'),
        elapsedTime: const Duration(minutes: 3, seconds: 12),
        lastSavedAt: DateTime.parse('2026-06-16T10:03:12.000'),
        completed: false,
        difficultyLabel: 'Tutorial',
        estimatedSolveTime: const Duration(minutes: 1),
        actualSolveTime: null,
      );

  void expectGridEquals(List<List<int>> a, List<List<int>> b) {
    expect(a.length, b.length);
    for (var r = 0; r < a.length; r++) {
      expect(a[r], b[r], reason: 'row $r mismatch');
    }
  }

  test('snapshot serializes to JSON with Phase 0 token forms', () {
    final json = sample().toJson();
    expect(json['game_id'], 'runic_sudoku');
    expect(json['grid_size'], '6x6');
    expect(json['box_shape'], '2x3');
    expect(json['elapsed_time'], 192000); // 3m12s in ms
    expect(json['actual_solve_time'], isNull);
    // Must be encodable to a real JSON string.
    expect(() => jsonEncode(json), returnsNormally);
  });

  test('snapshot can be restored from JSON', () {
    final restored = RunicSudokuSnapshot.fromJson(sample().toJson());
    expect(restored.levelId, 'rs_quick_test');
    expect(restored.gridSize, const GridDimensions(rows: 6, cols: 6));
    expect(restored.boxShape, const BoxShape(rows: 2, cols: 3));
  });

  test('restored snapshot matches the original (full round-trip)', () {
    final original = sample();
    // Round-trip through an actual JSON string, like the save repository does.
    final restored = RunicSudokuSnapshot.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(restored.gameId, original.gameId);
    expect(restored.levelId, original.levelId);
    expect(restored.seed, original.seed);
    expect(restored.gridSize, original.gridSize);
    expect(restored.boxShape, original.boxShape);
    expectGridEquals(restored.solutionGrid, original.solutionGrid);
    expectGridEquals(restored.givenCells, original.givenCells);
    expectGridEquals(restored.currentGrid, original.currentGrid);
    expect(restored.notesGrid, original.notesGrid);
    expect(restored.mistakesCount, original.mistakesCount);
    expect(restored.hintsUsed, original.hintsUsed);
    expect(restored.startedAt, original.startedAt);
    expect(restored.elapsedTime, original.elapsedTime);
    expect(restored.lastSavedAt, original.lastSavedAt);
    expect(restored.completed, original.completed);
    expect(restored.difficultyLabel, original.difficultyLabel);
    expect(restored.estimatedSolveTime, original.estimatedSolveTime);
    expect(restored.actualSolveTime, original.actualSolveTime);
  });

  test('completed snapshot round-trips actual_solve_time', () {
    final completed = sample().copyWith(
      completed: true,
      actualSolveTime: const Duration(minutes: 4, seconds: 30),
    );
    final restored = RunicSudokuSnapshot.fromJson(
      jsonDecode(jsonEncode(completed.toJson())) as Map<String, dynamic>,
    );
    expect(restored.completed, isTrue);
    expect(restored.actualSolveTime, const Duration(minutes: 4, seconds: 30));
  });
}
