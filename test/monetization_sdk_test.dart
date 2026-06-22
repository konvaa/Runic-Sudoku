import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/ads/admob_ads_service.dart';
import 'package:runic_sudoku/core/ads/ads_service.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/purchases/noop_purchase_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';

const _analytics = NoopAnalyticsService(echoToConsole: false);

/// Configurable fake ads service for the reward → hint contract test.
class _FakeAds implements AdsService {
  final bool reward;
  const _FakeAds({required this.reward});

  @override
  Future<AdResult> showRewardedAd({String? placement}) async => reward
      ? AdResult.completed(placement: placement)
      : AdResult.skipped(placement: placement);

  @override
  Future<AdResult> showInterstitial({String? placement}) async =>
      AdResult.shown(placement: placement);

  @override
  Future<bool> isAdAvailable({String? placement}) async => true;
}

/// Mirrors the screen's hint gating: reveal a hint only if the rewarded ad
/// granted a reward.
Future<bool> _grantHintIfRewarded(
    AdsService ads, RunicSudokuController c) async {
  final result = await ads.showRewardedAd(placement: 'hint');
  if (result.rewardGranted) {
    await c.revealNextHint();
    return true;
  }
  return false;
}

Future<AppController> _app() => AppController.load(
      saveService: LocalSaveRepository(),
      analytics: _analytics,
    );

void main() {
  group('Remove Ads suppresses interstitials (AdMob)', () {
    test('suppressed → interstitial is never shown or available', () async {
      final ads = AdMobAdsService(interstitialsSuppressed: () => true);
      final result = await ads.showInterstitial(placement: 'level_complete');
      expect(result.status, AdStatus.notAvailable);
      expect(await ads.isAdAvailable(placement: 'level_complete'), isFalse);
    });

    test('not suppressed but nothing loaded → reports unavailable, no crash',
        () async {
      final ads = AdMobAdsService(); // not suppressed, no ad pre-loaded
      expect(await ads.isAdAvailable(placement: 'level_complete'), isFalse);
    });
  });

  group('Remove Ads entitlement sync at startup', () {
    test('grants the entitlement when the store reports it owned', () async {
      final app = await _app();
      expect(app.removeAdsPurchased, isFalse);

      await app.syncRemoveAdsEntitlement(
          NoopPurchaseService(removeAdsOwned: true));
      expect(app.removeAdsPurchased, isTrue,
          reason: 'Remove Ads restored from the store');
    });

    test('never grants when not owned, and never revokes an existing one',
        () async {
      final app = await _app();
      await app.syncRemoveAdsEntitlement(
          NoopPurchaseService(removeAdsOwned: false));
      expect(app.removeAdsPurchased, isFalse);

      // A previously-purchased entitlement must survive a "not owned" query.
      await app.setRemoveAdsPurchased();
      await app.syncRemoveAdsEntitlement(
          NoopPurchaseService(removeAdsOwned: false));
      expect(app.removeAdsPurchased, isTrue);
    });
  });

  group('Rewarded ad → hint contract', () {
    Future<RunicSudokuController> controller() =>
        RunicSudokuController.loadOrCreate(
          puzzle: notesTestPuzzle, // has empty cells to hint
          saveService: LocalSaveRepository(),
          analytics: _analytics,
          fresh: true,
        );

    test('a completed rewarded ad reveals a hint', () async {
      final c = await controller();
      final before = c.hintsUsed;
      final granted = await _grantHintIfRewarded(const _FakeAds(reward: true), c);
      expect(granted, isTrue);
      expect(c.hintsUsed, before + 1, reason: 'hint revealed after reward');
    });

    test('a skipped rewarded ad does NOT reveal a hint', () async {
      final c = await controller();
      final before = c.hintsUsed;
      final granted =
          await _grantHintIfRewarded(const _FakeAds(reward: false), c);
      expect(granted, isFalse);
      expect(c.hintsUsed, before, reason: 'no hint without a reward');
    });
  });
}
