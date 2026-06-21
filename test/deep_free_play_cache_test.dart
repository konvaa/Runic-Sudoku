import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/freeplay/deep_free_play_cache.dart';
import 'package:runic_sudoku/games/runic_sudoku/freeplay/deep_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/level_data.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

const _solution = [
  [1, 2, 3, 4, 5, 6],
  [4, 5, 6, 1, 2, 3],
  [2, 3, 1, 5, 6, 4],
  [5, 6, 4, 2, 3, 1],
  [3, 1, 2, 6, 4, 5],
  [6, 4, 5, 3, 1, 2],
];

LevelData _level(int marker) => LevelData(
      gridSize: const GridDimensions(rows: 6, cols: 6),
      boxShape: const BoxShape(rows: 2, cols: 3),
      solutionGrid: _solution,
      givenCells: [
        for (var r = 0; r < 6; r++)
          [for (var c = 0; c < 6; c++) (r == 0 && c == 0) ? marker : 0],
      ],
      difficultyLabel: 'Deep',
      estimatedSolveTime: const Duration(seconds: 400),
    );

DeepPuzzleEntry _entry(String id, int marker) =>
    DeepPuzzleEntry(puzzleId: id, data: _level(marker));

Map<String, dynamic> _fakeJson(int n) => {
      'grid_size': '6x6',
      'box_shape': '2x3',
      'solution_grid': _solution,
      'given_cells': [
        for (var r = 0; r < 6; r++)
          [for (var c = 0; c < 6; c++) (r == 0 && c == 0) ? n + 1 : 0],
      ],
      'difficulty_label': 'Deep',
      'estimated_solve_time': 400000,
    };

Future<AppController> _app() => AppController.load(
      saveService: LocalSaveRepository(),
      analytics: const NoopAnalyticsService(echoToConsole: false),
    );

void main() {
  test('nextPuzzle consumes the rolling cache first', () async {
    final app = await _app();
    final store = InMemorySaveStore();
    await store.put(
      DeepFreePlayCache.cacheKey,
      jsonEncode([_entry('deep_c_aaa', 1).toJson()]),
    );
    final cache = DeepFreePlayCache(
      store: store,
      appController: app,
      bundledPool: [_entry('deep_fp_000', 9)],
      generate: () async => null,
    );

    final got = await cache.nextPuzzle();
    expect(got!.puzzleId, 'deep_c_aaa', reason: 'cache has priority');
    expect(cache.cacheSize, 0, reason: 'cache entry consumed');
    expect(app.deepUsedIds.contains('deep_c_aaa'), isTrue);
  });

  test('nextPuzzle falls back to the bundled pool when the cache is empty',
      () async {
    final app = await _app();
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: [_entry('deep_fp_000', 1), _entry('deep_fp_001', 2)],
      generate: () async => null,
    );

    final got = await cache.nextPuzzle();
    expect(got, isNotNull);
    expect(got!.puzzleId.startsWith('deep_fp_'), isTrue);
    expect(app.deepUsedIds.contains(got.puzzleId), isTrue);
  });

  test('nextPuzzle prefers an unseen bundled puzzle', () async {
    final app = await _app();
    await app.markDeepUsed('deep_fp_000');
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: [_entry('deep_fp_000', 1), _entry('deep_fp_001', 2)],
      generate: () async => null,
    );

    final got = await cache.nextPuzzle();
    expect(got!.puzzleId, 'deep_fp_001', reason: 'the unseen one is preferred');
  });

  test('nextPuzzle returns null only when both layers are empty', () async {
    final app = await _app();
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: const [],
      generate: () async => null,
    );
    expect(await cache.nextPuzzle(), isNull);
  });

  test('startRefill fills the cache to maxCacheSize', () async {
    final app = await _app();
    var n = 0;
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: const [],
      generate: () async => _fakeJson(n++),
    );

    cache.startRefill();
    await cache.refillTask;
    expect(cache.cacheSize, DeepFreePlayCache.maxCacheSize);
    expect(cache.hasCache, isTrue);
  });

  test('stopRefill cancels background generation', () async {
    final app = await _app();
    var n = 0;
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: const [],
      generate: () async => _fakeJson(n++),
    );

    cache.startRefill();
    cache.stopRefill(); // before the first generated puzzle is committed
    await cache.refillTask;
    expect(cache.cacheSize, 0,
        reason: 'an in-flight result after stop is discarded');
  });

  test('refill de-duplicates and never spins forever on a constant generator',
      () async {
    final app = await _app();
    // Always returns the SAME puzzle: exactly one unique entry lands, then the
    // consecutive-miss bound stops the loop (no infinite spin).
    final cache = DeepFreePlayCache(
      store: InMemorySaveStore(),
      appController: app,
      bundledPool: const [],
      generate: () async => _fakeJson(7),
    );
    cache.startRefill();
    await cache.refillTask;
    expect(cache.cacheSize, 1, reason: 'identical puzzles are de-duplicated');
  });
}
