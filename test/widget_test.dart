// Smoke test for the app shell. Replaces the default `flutter create`
// widget_test.dart, which referenced a non-existent `MyApp`.

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/app/app.dart';
import 'package:runic_sudoku/core/ads/noop_ads_service.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/purchases/noop_purchase_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/core/theme/theme_manager.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression_controller.dart';

void main() {
  testWidgets('main menu renders Daily / Rune Trials / Settings', (tester) async {
    final save = LocalSaveRepository();
    const analytics = NoopAnalyticsService(echoToConsole: false);
    final appController =
        await AppController.load(saveService: save, analytics: analytics);
    final levelPool = LevelPool.fromJsonString('{"levels":[]}');
    final progression = Progression.fromPool(levelPool);
    final progressionController =
        ProgressionController(app: appController, progression: progression);

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
    );

    await tester.pumpWidget(RunicSudokuApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Daily Puzzle'), findsOneWidget);
    expect(find.text('Rune Trials'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
