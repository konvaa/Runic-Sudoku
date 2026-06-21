import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/freeplay/deep_pool.dart';

const _expectedSize = 75;

int _boxOf(int r, int c) => (r ~/ 2) * 2 + (c ~/ 3);

bool _isCompleteSolution(List<List<int>> g) {
  if (g.length != 6 || g.any((row) => row.length != 6)) return false;
  bool ok(List<int> vs) => (vs.toList()..sort()).toString() == '[1, 2, 3, 4, 5, 6]';
  for (var r = 0; r < 6; r++) {
    if (!ok([for (var c = 0; c < 6; c++) g[r][c]])) return false;
  }
  for (var c = 0; c < 6; c++) {
    if (!ok([for (var r = 0; r < 6; r++) g[r][c]])) return false;
  }
  for (var b = 0; b < 6; b++) {
    if (!ok([
      for (var r = 0; r < 6; r++)
        for (var c = 0; c < 6; c++)
          if (_boxOf(r, c) == b) g[r][c],
    ])) {
      return false;
    }
  }
  return true;
}

void main() {
  test('bundled Deep pool asset is present, valid and unique', () {
    final file = File(DeepBundledPool.assetPath);
    expect(file.existsSync(), isTrue,
        reason: 'run tool/generate_freeplay_deep_pool.dart to build it');

    final entries = DeepBundledPool.fromJsonString(file.readAsStringSync());
    expect(entries.length, _expectedSize);

    final ids = <String>{};
    final givens = <String>{};
    for (final e in entries) {
      expect(ids.add(e.puzzleId), isTrue, reason: 'duplicate id ${e.puzzleId}');
      final d = e.data;
      expect(d.difficultyLabel, 'Deep');
      expect(d.gridSize.rows, 6);
      expect(d.gridSize.cols, 6);
      expect(_isCompleteSolution(d.solutionGrid), isTrue,
          reason: '${e.puzzleId} has an invalid solution grid');

      var givenCount = 0;
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 6; c++) {
          final g = d.givenCells[r][c];
          if (g != 0) {
            expect(g, d.solutionGrid[r][c],
                reason: '${e.puzzleId} given not a subset of its solution');
            givenCount++;
          }
        }
      }
      expect(givenCount, greaterThan(0));
      expect(givens.add(d.givenCells.toString()), isTrue,
          reason: 'duplicate given pattern in ${e.puzzleId}');
    }
  });
}
