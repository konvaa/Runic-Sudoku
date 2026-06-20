import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/core/save/shared_preferences_save_store.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression_controller.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('SharedPreferencesSaveStore round-trips values', () async {
    final store = await SharedPreferencesSaveStore.create();
    expect(await store.containsKey('app/profile'), isFalse);

    await store.put('app/profile', '{"x":1}');
    expect(await store.get('app/profile'), '{"x":1}');
    expect(await store.containsKey('app/profile'), isTrue);

    await store.remove('app/profile');
    expect(await store.get('app/profile'), isNull);
  });

  test('profile persists across a simulated restart', () async {
    const analytics = NoopAnalyticsService(echoToConsole: false);

    // ---- First launch: buy remove-ads, finish a CAMPAIGN level + a DAILY ----
    final app1 = await AppController.load(
      saveService:
          LocalSaveRepository(store: await SharedPreferencesSaveStore.create()),
      analytics: analytics,
    );
    await app1.setRemoveAdsPurchased();
    await app1.onLevelCompleted('rs_005'); // campaign -> counts as completed
    await app1.onLevelCompleted('rs_001',
        isDaily: true, date: DateTime(2026, 6, 1)); // daily -> streak only
    expect(app1.removeAdsPurchased, isTrue);
    expect(app1.isCompleted('rs_005'), isTrue);
    expect(app1.isCompleted('rs_001'), isFalse,
        reason: 'daily must not count as a campaign completion');
    expect(app1.dailyStreak, 1);

    // ---- Restart: a fresh controller over the same backing prefs ----
    final app2 = await AppController.load(
      saveService:
          LocalSaveRepository(store: await SharedPreferencesSaveStore.create()),
      analytics: analytics,
    );
    expect(app2.removeAdsPurchased, isTrue, reason: 'remove-ads persisted');
    expect(app2.isCompleted('rs_005'), isTrue,
        reason: 'campaign completion persisted');
    expect(app2.isCompleted('rs_001'), isFalse,
        reason: 'daily still does not count after restart');
    expect(app2.dailyStreak, 1, reason: 'streak persisted');

    // ---- Next day extends the streak (not reset) ----
    await app2.onLevelCompleted('rs_002',
        isDaily: true, date: DateTime(2026, 6, 2));
    expect(app2.dailyStreak, 2);
  });

  test('campaign progression persists across a simulated restart', () async {
    const analytics = NoopAnalyticsService(echoToConsole: false);
    final pool = LevelPool([
      _lvl('q0', 'Quick'),
      _lvl('q1', 'Quick'),
      _lvl('q2', 'Quick'),
    ]);
    final progression = Progression.fromPool(pool, chapterUnlockFraction: 0.5);

    // ---- First launch ----
    final app1 = await AppController.load(
      saveService:
          LocalSaveRepository(store: await SharedPreferencesSaveStore.create()),
      analytics: analytics,
    );
    final pc1 = ProgressionController(app: app1, progression: progression);
    await pc1.ensureInitialized();
    expect(pc1.isLevelUnlocked('q0'), isTrue);
    expect(pc1.isLevelUnlocked('q1'), isFalse);

    await pc1.recordCompletion('q0');
    expect(pc1.isLevelUnlocked('q1'), isTrue);

    // ---- Restart ----
    final app2 = await AppController.load(
      saveService:
          LocalSaveRepository(store: await SharedPreferencesSaveStore.create()),
      analytics: analytics,
    );
    final pc2 = ProgressionController(app: app2, progression: progression);
    expect(app2.isCompleted('q0'), isTrue, reason: 'completion persisted');
    expect(pc2.isLevelUnlocked('q1'), isTrue, reason: 'unlock derived after restart');
    expect(app2.unlockedLevelIds.contains('q1'), isTrue,
        reason: 'persisted unlocked set');
  });
}
