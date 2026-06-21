import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/ads/noop_ads_service.dart';
import 'core/analytics/noop_analytics_service.dart';
import 'core/profile/app_controller.dart';
import 'core/purchases/noop_purchase_service.dart';
import 'core/save/local_save_repository.dart';
import 'core/save/shared_preferences_save_store.dart';
import 'core/theme/theme_manager.dart';
import 'games/runic_sudoku/freeplay/deep_free_play_cache.dart';
import 'games/runic_sudoku/freeplay/deep_pool.dart';
import 'games/runic_sudoku/level_pool.dart';
import 'games/runic_sudoku/progression.dart';
import 'games/runic_sudoku/progression_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark fantasy look: light status/nav-bar icons over the dark backgrounds.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Real ads/billing SDKs swap in here in Phase 4; everything else is unchanged.
  // Durable storage so the profile + level saves survive app restarts.
  final store = await SharedPreferencesSaveStore.create();
  final save = LocalSaveRepository(store: store);
  const analytics = NoopAnalyticsService();

  final levelPool = await LevelPool.loadFromAsset();
  final appController =
      await AppController.load(saveService: save, analytics: analytics);
  await appController.onSessionStart();

  // Campaign progression: build chapters from the pool and ensure unlock state
  // is derived (a fresh profile gets the first level unlocked).
  final progression = Progression.fromPool(levelPool);
  final progressionController =
      ProgressionController(app: appController, progression: progression);
  await progressionController.ensureInitialized();

  // Deep Free Play supply (Phase 3.66.1): bundled pool + rolling cache. Load the
  // persisted cache; if it is low, start background refill immediately, otherwise
  // defer it (the Free Play entry / leaving the first puzzle will trigger it) so
  // it never competes with startup.
  final deepPool = await DeepBundledPool.loadFromAsset();
  final deepCache = DeepFreePlayCache(
    store: store,
    appController: appController,
    bundledPool: deepPool,
  );
  await deepCache.load();
  if (deepCache.cacheSize < 5) deepCache.startRefill();

  final services = AppServices(
    save: save,
    analytics: analytics,
    ads: const NoopAdsService(),
    purchases: NoopPurchaseService(),
    themeManager: ThemeManager(),
    appController: appController,
    levelPool: levelPool,
    progression: progression,
    progressionController: progressionController,
    deepCache: deepCache,
  );

  runApp(RunicSudokuApp(services: services));
}
