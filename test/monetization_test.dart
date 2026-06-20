import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/monetization/monetization_policy.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/profile/player_profile.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';

void main() {
  PlayerProfile profile() => PlayerProfile(firstOpenTimestamp: DateTime(2026));

  group('MonetizationPolicy.shouldShowInterstitial', () {
    test('fires only once the cadence threshold is reached', () {
      final p = profile();
      p.levelsSinceInterstitial = 2;
      expect(MonetizationPolicy.shouldShowInterstitial(p), isFalse);
      p.levelsSinceInterstitial = 3;
      expect(MonetizationPolicy.shouldShowInterstitial(p), isTrue);
    });

    test('never fires once ads are removed', () {
      final p = profile()
        ..levelsSinceInterstitial = 99
        ..removeAdsPurchased = true;
      expect(MonetizationPolicy.shouldShowInterstitial(p), isFalse);
    });
  });

  group('MonetizationPolicy.shouldShowRemoveAdsOffer', () {
    test('shows after enough completed levels + interstitials', () {
      final p = profile()
        ..completedLevelsCount = 5
        ..interstitialsSinceLastOffer = 2;
      expect(
          MonetizationPolicy.shouldShowRemoveAdsOffer(p, Duration.zero), isTrue);
    });

    test('shows via the session-duration path', () {
      final p = profile()
        ..completedLevelsCount = 1
        ..interstitialsSinceLastOffer = 2;
      expect(
        MonetizationPolicy.shouldShowRemoveAdsOffer(
            p, const Duration(minutes: 12)),
        isTrue,
      );
    });

    test('suppressed until enough interstitials since last offer', () {
      final p = profile()
        ..completedLevelsCount = 50
        ..interstitialsSinceLastOffer = 1;
      expect(
          MonetizationPolicy.shouldShowRemoveAdsOffer(p, Duration.zero), isFalse);
    });

    test('suppressed when purchased or after the lifetime cap', () {
      final bought = profile()
        ..completedLevelsCount = 50
        ..interstitialsSinceLastOffer = 9
        ..removeAdsPurchased = true;
      expect(MonetizationPolicy.shouldShowRemoveAdsOffer(bought, Duration.zero),
          isFalse);

      final capped = profile()
        ..completedLevelsCount = 50
        ..interstitialsSinceLastOffer = 9
        ..removeAdsOfferShownCount = MonetizationPolicy.maxOffersLifetime;
      expect(MonetizationPolicy.shouldShowRemoveAdsOffer(capped, Duration.zero),
          isFalse);
    });
  });

  group('AppController', () {
    Future<AppController> controller() => AppController.load(
          saveService: LocalSaveRepository(),
          analytics: const NoopAnalyticsService(echoToConsole: false),
        );

    test('interstitial is shown on cadence, not every level', () async {
      final app = await controller();
      final shownAt = <int>[];
      for (var lv = 1; lv <= 7; lv++) {
        await app.onLevelCompleted('rs_$lv');
        if (app.shouldShowInterstitial()) {
          shownAt.add(lv);
          await app.markInterstitialShown();
        }
      }
      // Every 3rd completion -> after #3 and #6.
      expect(shownAt, [3, 6]);
    });

    test('daily streak increments on consecutive days and resets on a gap',
        () async {
      final app = await controller();
      await app.onLevelCompleted('d', isDaily: true, date: DateTime(2026, 6, 1));
      expect(app.dailyStreak, 1);
      await app.onLevelCompleted('d', isDaily: true, date: DateTime(2026, 6, 2));
      expect(app.dailyStreak, 2);
      // same day again -> unchanged
      await app.onLevelCompleted('d', isDaily: true, date: DateTime(2026, 6, 2));
      expect(app.dailyStreak, 2);
      // a day skipped -> reset to 1
      await app.onLevelCompleted('d', isDaily: true, date: DateTime(2026, 6, 5));
      expect(app.dailyStreak, 1);
    });

    test('completed level ids dedupe the completed count', () async {
      final app = await controller();
      await app.onLevelCompleted('rs_001');
      await app.onLevelCompleted('rs_001'); // replay
      await app.onLevelCompleted('rs_002');
      expect(app.profile.completedLevelsCount, 2);
      expect(app.isCompleted('rs_001'), isTrue);
    });
  });
}
