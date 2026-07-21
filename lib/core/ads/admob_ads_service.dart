import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

/// AdMob ad unit ids. Test units are used in every non-release build so we never
/// risk policy violations while developing; the real units ship only in release.
class AdUnitIds {
  const AdUnitIds._();

  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const _prodInterstitial = 'ca-app-pub-5765817950667437/7331851214';
  static const _prodRewarded = 'ca-app-pub-5765817950667437/3743694069';

  static String get interstitial =>
      kReleaseMode ? _prodInterstitial : _testInterstitial;
  static String get rewarded => kReleaseMode ? _prodRewarded : _testRewarded;
}

/// Real AdMob implementation of [AdsService] (Phase 4).
///
/// - Interstitial + rewarded ads are pre-fetched and re-loaded after each show.
/// - Interstitials are suppressed entirely when Remove Ads is owned (no load, no
///   show) via [interstitialsSuppressed]; rewarded ads always remain available.
/// - If an ad is not ready, the call returns gracefully ([AdStatus.notAvailable]
///   / [AdStatus.failed]) and never blocks the UI.
///
/// Requires [MobileAds.instance.initialize] to have completed first — which
/// happens only when UMP consent allows ad requests (see
/// `UmpConsent.gatherConsentThenInitialize`; `main.dart` wires the no-op
/// service otherwise). Every load additionally re-checks
/// `ConsentInformation.canRequestAds()`, so a consent withdrawal (privacy
/// options form in Settings) stops new ad requests without an app restart.
/// Falls back cleanly: every public method that can't proceed returns a
/// non-throwing result.
class AdMobAdsService implements AdsService {
  /// Returns true when interstitials should be suppressed (Remove Ads owned).
  final bool Function()? interstitialsSuppressed;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  AdMobAdsService({this.interstitialsSuppressed});

  bool get _suppressed => interstitialsSuppressed?.call() ?? false;

  /// UMP consent gate, re-checked before EVERY ad request: consent can change
  /// mid-session (privacy options form in Settings), and no request may leave
  /// the app unless `canRequestAds()` is true at that moment. Returns false
  /// when the consent state cannot be determined.
  static Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false; // unknown consent state — do not request ads
    }
  }

  /// Pre-fetch both formats. Call once after [MobileAds] is initialized.
  void preload() {
    _loadInterstitial();
    _loadRewarded();
  }

  // ---- Interstitial -------------------------------------------------------

  Future<void> _loadInterstitial() async {
    if (_suppressed) return; // never pre-fetch when Remove Ads is owned
    if (!await _canRequestAds()) return; // UMP consent gate
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<AdResult> showInterstitial({String? placement}) async {
    if (_suppressed) return AdResult.notAvailable(placement: placement);
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial(); // prepare one for next time
      return AdResult.notAvailable(placement: placement);
    }
    _interstitial = null;
    final completer = Completer<AdResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        if (!completer.isCompleted) {
          completer.complete(AdResult.shown(placement: placement));
        }
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
        if (!completer.isCompleted) {
          completer.complete(
              AdResult.failed(placement: placement, message: e.message));
        }
      },
    );
    await ad.show();
    return completer.future;
  }

  // ---- Rewarded -----------------------------------------------------------

  Future<void> _loadRewarded() async {
    if (!await _canRequestAds()) return; // UMP consent gate
    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  @override
  Future<AdResult> showRewardedAd({String? placement}) async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded(); // prepare one for next time
      return AdResult.failed(
          placement: placement, message: 'No rewarded ad ready');
    }
    _rewarded = null;
    final completer = Completer<AdResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!completer.isCompleted) {
          completer.complete(earned
              ? AdResult.completed(placement: placement)
              : AdResult.skipped(placement: placement));
        }
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        if (!completer.isCompleted) {
          completer.complete(
              AdResult.failed(placement: placement, message: e.message));
        }
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return completer.future;
  }

  @override
  Future<bool> isAdAvailable({String? placement}) async {
    if (placement == 'hint' || placement == 'mistake_check') {
      return _rewarded != null;
    }
    return !_suppressed && _interstitial != null;
  }

  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
  }
}
