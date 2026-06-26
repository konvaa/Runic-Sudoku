import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/app.dart';
import 'core/ads/admob_ads_service.dart';
import 'core/ads/ads_service.dart';
import 'core/ads/noop_ads_service.dart';
import 'core/ads/ump_consent.dart';
import 'core/analytics/noop_analytics_service.dart';
import 'core/profile/app_controller.dart';
import 'core/purchases/noop_purchase_service.dart';
import 'core/purchases/play_billing_service.dart';
import 'core/purchases/purchase_service.dart';
import 'core/save/local_save_repository.dart';
import 'core/save/shared_preferences_save_store.dart';
import 'core/theme/theme_manager.dart';
import 'firebase_options.dart';
import 'games/runic_sudoku/freeplay/deep_free_play_cache.dart';
import 'games/runic_sudoku/freeplay/deep_pool.dart';
import 'games/runic_sudoku/level_pool.dart';
import 'games/runic_sudoku/progression.dart';
import 'games/runic_sudoku/progression_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- 1. Firebase + Crashlytics (MUST be before AdMob). Non-fatal on error.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase unavailable (e.g. unsupported platform) — run without reporting.
  }

  // Dark fantasy look: light status/nav-bar icons over the dark backgrounds.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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

  // Deep Free Play supply (Phase 3.66.1): bundled pool + rolling cache.
  final deepPool = await DeepBundledPool.loadFromAsset();
  final deepCache = DeepFreePlayCache(
    store: store,
    appController: appController,
    bundledPool: deepPool,
  );
  await deepCache.load();
  if (deepCache.cacheSize < 5) deepCache.startRefill();

  // ---- 2 + 3. UMP consent → AdMob init → real ads (Phase 4). Falls back to the
  // no-op service if anything goes wrong, so ads issues never block the game.
  AdsService ads;
  try {
    await UmpConsent.gatherConsentThenInitialize();
    MobileAds.instance.updateRequestConfiguration(
      // TODO: add your test device's GAID so you see real test ads on it.
      // Find it in: Android Settings → Google → Ads → Advertising ID.
      RequestConfiguration(testDeviceIds: const ['2599f83f-cbd7-4507-bc79-ec834e09e4bb']),
    );
    final admob = AdMobAdsService(
      interstitialsSuppressed: () => appController.removeAdsPurchased,
    );
    admob.preload();
    ads = admob;
  } catch (_) {
    ads = const NoopAdsService();
  }

  // ---- 4. Billing init + entitlement sync (so Remove Ads survives reinstall).
  PurchaseService purchases;
  try {
    final billing = PlayBillingService();
    await billing.initialize();
    purchases = billing;
  } catch (_) {
    purchases = NoopPurchaseService();
  }
  await appController.syncRemoveAdsEntitlement(purchases);

  // ---- 5. Run the app UI.
  final services = AppServices(
    save: save,
    analytics: analytics,
    ads: ads,
    purchases: purchases,
    themeManager: ThemeManager(),
    appController: appController,
    levelPool: levelPool,
    progression: progression,
    progressionController: progressionController,
    deepCache: deepCache,
  );

  runApp(RunicSudokuApp(services: services));
}
