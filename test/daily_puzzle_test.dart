import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/daily_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';

void main() {
  group('DailyPuzzleSelector', () {
    test('same calendar date -> same index (ignores time of day)', () {
      final a = DailyPuzzleSelector.indexForDate(DateTime(2026, 6, 18), 70);
      final b =
          DailyPuzzleSelector.indexForDate(DateTime(2026, 6, 18, 23, 59), 70);
      expect(a, b);
    });

    test('index is always within range', () {
      for (var d = 0; d < 120; d++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: d));
        final i = DailyPuzzleSelector.indexForDate(date, 70);
        expect(i, inInclusiveRange(0, 69));
      }
    });

    test('different dates spread across the pool (not stuck on one level)', () {
      final idxs = [
        for (var d = 0; d < 60; d++)
          DailyPuzzleSelector.indexForDate(
              DateTime(2026, 1, 1).add(Duration(days: d)), 70),
      ];
      // Healthy spread, and not a trivial "same level all month".
      expect(idxs.toSet().length, greaterThan(20));
      var consecutiveSame = 0;
      for (var i = 1; i < idxs.length; i++) {
        if (idxs[i] == idxs[i - 1]) consecutiveSame++;
      }
      expect(consecutiveSame, lessThan(3));
    });

    test('throws on empty pool', () {
      expect(() => DailyPuzzleSelector.indexForDate(DateTime(2026, 1, 1), 0),
          throwsArgumentError);
    });
  });

  group('LevelPool', () {
    const json = '''
    {"levels":[
      {"grid_size":"6x6","box_shape":"2x3","difficulty_label":"Quick",
       "estimated_solve_time":59000,"seed":1,
       "solution_grid":[[1,2,3,4,5,6],[4,5,6,1,2,3],[2,3,1,5,6,4],[5,6,4,2,3,1],[3,1,2,6,4,5],[6,4,5,3,1,2]],
       "given_cells":[[1,2,3,4,5,6],[4,5,6,1,2,3],[2,3,1,5,6,4],[5,6,4,2,3,1],[3,1,2,6,0,0],[6,4,5,3,0,0]]},
      {"grid_size":"6x6","box_shape":"2x3","difficulty_label":"Tricky",
       "estimated_solve_time":288000,"seed":2,
       "solution_grid":[[1,2,3,4,5,6],[4,5,6,1,2,3],[2,3,1,5,6,4],[5,6,4,2,3,1],[3,1,2,6,4,5],[6,4,5,3,1,2]],
       "given_cells":[[1,0,3,0,5,6],[4,5,0,1,2,3],[2,3,1,0,6,4],[5,6,4,2,3,1],[0,1,2,6,4,5],[6,4,5,3,1,2]]}
    ]}''';

    test('parses entries and derives stable ids', () {
      final pool = LevelPool.fromJsonString(json);
      expect(pool.length, 2);
      expect(pool.levels[0].levelId, 'rs_000');
      expect(pool.levels[1].levelId, 'rs_001');
      expect(pool.levels[0].difficultyLabel, 'Quick');
      expect(pool.levels[0].estimatedSolveTime, const Duration(seconds: 59));
      expect(pool.byId('rs_001')?.difficultyLabel, 'Tricky');
    });

    test('groups by label in display order', () {
      final pool = LevelPool.fromJsonString(json);
      expect(pool.presentLabels, ['Quick', 'Tricky']);
      expect(pool.byLabel('Quick').length, 1);
    });

    test('dailyFor is deterministic for a date', () {
      final pool = LevelPool.fromJsonString(json);
      final a = pool.dailyFor(DateTime(2026, 6, 18));
      final b = pool.dailyFor(DateTime(2026, 6, 18, 8));
      expect(a.levelId, b.levelId);
    });
  });
}
