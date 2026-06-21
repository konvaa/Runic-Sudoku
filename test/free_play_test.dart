import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/profile/player_profile.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression_controller.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

ManualPuzzle _lvl(String id, String label) => ManualPuzzle(
      levelId: id,
      seed: 0,
      gridSize: const GridDimensions(rows: 1, cols: 1),
      boxShape: const BoxShape(rows: 1, cols: 1),
      solutionGrid: const [
        [1]
      ],
      givenCells: const [
        [0]
      ],
      difficultyLabel: label,
      estimatedSolveTime: const Duration(minutes: 1),
    );

void main() {
  // 3 Quick + 2 Normal. Chapter 1 (Quick) threshold = ceil(3 * 0.5) = 2.
  LevelPool pool() => LevelPool([
        _lvl('q0', 'Quick'), _lvl('q1', 'Quick'), _lvl('q2', 'Quick'),
        _lvl('n0', 'Normal'), _lvl('n1', 'Normal'),
      ]);
  Progression prog() => Progression.fromPool(pool(), chapterUnlockFraction: 0.5);

  group('Free Play unlock (Phase 3.66)', () {
    test('locked until the Quick Runes chapter is completed to threshold', () {
      final p = prog();
      expect(p.isFreePlayUnlocked(<String>{}), isFalse);
      expect(p.isFreePlayUnlocked({'q0'}), isFalse);
      expect(p.isFreePlayUnlocked({'q0', 'q1'}), isTrue);
      // Daily/other-chapter completions of non-Quick levels do not count.
      expect(p.isFreePlayUnlocked({'n0', 'n1'}), isFalse);
    });

    test('ProgressionController derives freePlayUnlocked live', () async {
      final app = await AppController.load(
        saveService: LocalSaveRepository(),
        analytics: const NoopAnalyticsService(echoToConsole: false),
      );
      final pc = ProgressionController(app: app, progression: prog());
      await pc.ensureInitialized();

      expect(pc.freePlayUnlocked, isFalse);
      await pc.recordCompletion('q0');
      expect(pc.freePlayUnlocked, isFalse);
      await pc.recordCompletion('q1'); // threshold reached
      expect(pc.freePlayUnlocked, isTrue);
    });

    test('daily completions never unlock Free Play', () async {
      final app = await AppController.load(
        saveService: LocalSaveRepository(),
        analytics: const NoopAnalyticsService(echoToConsole: false),
      );
      final pc = ProgressionController(app: app, progression: prog());
      await pc.ensureInitialized();

      await pc.recordCompletion('q0', isDaily: true, date: DateTime(2026, 6, 1));
      await pc.recordCompletion('q1', isDaily: true, date: DateTime(2026, 6, 2));
      expect(pc.freePlayUnlocked, isFalse,
          reason: 'daily must not feed the Quick chapter');
    });
  });

  group('Free Play stats (Phase 3.66)', () {
    Future<AppController> controller() => AppController.load(
          saveService: LocalSaveRepository(),
          analytics: const NoopAnalyticsService(echoToConsole: false),
        );

    test('completing increments count and records best time per difficulty',
        () async {
      final app = await controller();

      await app.onFreePlayCompleted('Quick', const Duration(seconds: 90));
      expect(app.freePlaysCompleted, 1);
      expect(app.bestFreePlayTime('Quick'), 90);
      expect(app.freePlaysCurrentStreak, 1);

      // A faster solve updates the best.
      await app.onFreePlayCompleted('Quick', const Duration(seconds: 60));
      expect(app.freePlaysCompleted, 2);
      expect(app.bestFreePlayTime('Quick'), 60);
      expect(app.freePlaysCurrentStreak, 2);

      // A slower solve does NOT regress the best.
      await app.onFreePlayCompleted('Quick', const Duration(seconds: 120));
      expect(app.freePlaysCompleted, 3);
      expect(app.bestFreePlayTime('Quick'), 60);

      // Best times are tracked per difficulty.
      await app.onFreePlayCompleted('Deep', const Duration(seconds: 300));
      expect(app.bestFreePlayTime('Deep'), 300);
      expect(app.bestFreePlayTime('Quick'), 60);
    });

    test('Free Play is isolated from campaign + daily, but feeds ad cadence',
        () async {
      final app = await controller();
      await app.onFreePlayCompleted('Tricky', const Duration(seconds: 200));
      await app.onFreePlayCompleted('Tricky', const Duration(seconds: 210));
      await app.onFreePlayCompleted('Tricky', const Duration(seconds: 220));

      expect(app.completedLevelIds, isEmpty,
          reason: 'Free Play must not touch completed_level_ids');
      expect(app.profile.completedLevelsCount, 0);
      expect(app.dailyStreak, 0, reason: 'Free Play must not touch daily');
      expect(app.profile.levelsSinceInterstitial, 3,
          reason: 'Free Play feeds the same interstitial cadence');
    });

    test('resetFreePlayStreak clears the streak only', () async {
      final app = await controller();
      await app.onFreePlayCompleted('Normal', const Duration(seconds: 100));
      await app.onFreePlayCompleted('Normal', const Duration(seconds: 100));
      expect(app.freePlaysCurrentStreak, 2);

      await app.resetFreePlayStreak();
      expect(app.freePlaysCurrentStreak, 0);
      expect(app.freePlaysCompleted, 2, reason: 'totals are preserved');
      expect(app.bestFreePlayTime('Normal'), 100);
    });

    test('Free Play stats survive a serialize round-trip', () async {
      final app = await controller();
      await app.onFreePlayCompleted('Deep', const Duration(seconds: 400));
      await app.onFreePlayCompleted('Quick', const Duration(seconds: 55));

      final json = app.profile.toJson();
      final restored = PlayerProfile.fromJson(json);
      expect(restored.freePlaysCompleted, 2);
      expect(restored.freePlaysBestTimes['Deep'], 400);
      expect(restored.freePlaysBestTimes['Quick'], 55);
    });
  });
}
