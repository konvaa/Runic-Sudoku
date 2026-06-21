import 'package:flutter/material.dart';

import '../core/ads/ads_service.dart';
import '../core/analytics/analytics_service.dart';
import '../core/profile/app_controller.dart';
import '../core/purchases/purchase_service.dart';
import '../core/save/save_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_manager.dart';
import '../games/runic_sudoku/freeplay/deep_free_play_cache.dart';
import '../games/runic_sudoku/level_pool.dart';
import '../games/runic_sudoku/manual_puzzle.dart';
import '../games/runic_sudoku/progression.dart';
import '../games/runic_sudoku/progression_controller.dart';
import '../games/runic_sudoku/runic_sudoku_screen.dart';
import '../games/runic_sudoku/solver/difficulty_constants.dart';
import 'free_play_screen.dart';
import 'level_select_screen.dart';
import 'main_menu_screen.dart';
import 'routes.dart';
import 'settings_screen.dart';

/// Simple service locator passed down through the widget tree by constructor.
///
/// Deliberately a plain object (no DI framework). Swap any no-op implementation
/// for a real one here and the rest of the app is unaffected.
class AppServices {
  final SaveService save;
  final AnalyticsService analytics;
  final AdsService ads;
  final PurchaseService purchases;
  final ThemeManager themeManager;

  /// App-wide player profile + monetization/session bookkeeping (Phase 3).
  final AppController appController;

  /// Pre-generated level pool loaded from assets (Phase 3).
  final LevelPool levelPool;

  /// Campaign progression metadata + rules (Phase 3.5).
  final Progression progression;
  final ProgressionController progressionController;

  /// Deep Free Play bundled-pool + rolling-cache supply (Phase 3.66.1). Optional
  /// so lightweight tests can omit it; production (`main.dart`) always wires it.
  final DeepFreePlayCache? deepCache;

  const AppServices({
    required this.save,
    required this.analytics,
    required this.ads,
    required this.purchases,
    required this.themeManager,
    required this.appController,
    required this.levelPool,
    required this.progression,
    required this.progressionController,
    this.deepCache,
  });
}

/// Builds the play screen for a puzzle, wiring in all the services it needs.
/// Used by both the level select and the daily-puzzle entry point.
extension PuzzleNavigation on AppServices {
  RunicSudokuScreen puzzleScreen(ManualPuzzle puzzle, {bool isDaily = false}) =>
      RunicSudokuScreen(
        puzzle: puzzle,
        saveService: save,
        analytics: analytics,
        symbolSet: themeManager.currentSymbolSet,
        ads: ads,
        purchases: purchases,
        appController: appController,
        progressionController: progressionController,
        isDaily: isDaily,
        deepCache: deepCache,
      );

  /// Builds a Free Play play screen (Phase 3.66): on-demand [puzzle] of [label],
  /// with [generateNext] driving the "Next Trial" loop.
  RunicSudokuScreen freePlayScreen(
    ManualPuzzle puzzle,
    DifficultyLabel label, {
    required Future<ManualPuzzle?> Function() generateNext,
    bool resume = false,
  }) =>
      RunicSudokuScreen(
        puzzle: puzzle,
        saveService: save,
        analytics: analytics,
        symbolSet: themeManager.currentSymbolSet,
        ads: ads,
        purchases: purchases,
        appController: appController,
        progressionController: progressionController,
        isFreePlay: true,
        freePlayLabel: label,
        generateNext: generateNext,
        deepCache: deepCache,
        freePlayResume: resume,
      );
}

/// Root widget. Rebuilds when the theme changes.
class RunicSudokuApp extends StatelessWidget {
  final AppServices services;

  const RunicSudokuApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: services.themeManager,
      builder: (context, _) {
        return MaterialApp(
          title: 'Runic Sudoku',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.fromRecord(services.themeManager.current),
          initialRoute: AppRoutes.mainMenu,
          onGenerateRoute: _generateRoute,
        );
      },
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.levelSelect:
        return MaterialPageRoute(
          builder: (_) => LevelSelectScreen(services: services),
          settings: settings,
        );
      case AppRoutes.freePlay:
        return MaterialPageRoute(
          builder: (_) => FreeDifficultySelectScreen(services: services),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(services: services),
          settings: settings,
        );
      case AppRoutes.mainMenu:
      default:
        return MaterialPageRoute(
          builder: (_) => MainMenuScreen(services: services),
          settings: settings,
        );
    }
  }
}
