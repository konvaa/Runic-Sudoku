/// Outcome status of an ad request. Phase 1 *internal* contract.
///
/// This is NOT assumed to map 1:1 to any real SDK. When AdMob / Unity Ads is
/// integrated later, an adapter maps SDK callbacks into these values.
enum AdStatus {
  /// Rewarded ad watched to completion (reward should be granted).
  completed,

  /// Interstitial (or non-rewarded) ad was shown to the user.
  shown,

  /// User dismissed/skipped before the reward threshold.
  skipped,

  /// Ad failed to load or show.
  failed,

  /// No ad available / ads disabled (e.g. remove-ads purchased).
  notAvailable,
}

/// Result of an ad request. Stable Phase 1 contract.
class AdResult {
  final AdStatus status;

  /// True only when a reward should be granted (rewarded ads completed).
  final bool rewardGranted;

  /// Optional placement identifier the request was made for.
  final String? placement;

  /// Optional human/debug message (e.g. failure reason).
  final String? message;

  const AdResult({
    required this.status,
    this.rewardGranted = false,
    this.placement,
    this.message,
  });

  const AdResult.completed({String? placement})
      : status = AdStatus.completed,
        rewardGranted = true,
        placement = placement,
        message = null;

  const AdResult.shown({String? placement})
      : status = AdStatus.shown,
        rewardGranted = false,
        placement = placement,
        message = null;

  const AdResult.skipped({String? placement})
      : status = AdStatus.skipped,
        rewardGranted = false,
        placement = placement,
        message = null;

  const AdResult.failed({String? placement, String? message})
      : status = AdStatus.failed,
        rewardGranted = false,
        placement = placement,
        message = message;

  const AdResult.notAvailable({String? placement})
      : status = AdStatus.notAvailable,
        rewardGranted = false,
        placement = placement,
        message = null;

  @override
  String toString() =>
      'AdResult($status, reward=$rewardGranted, placement=$placement)';
}

/// App-wide ads interface.
abstract class AdsService {
  /// Shows a rewarded ad. Resolves with [AdStatus.completed] and
  /// `rewardGranted == true` when the reward is earned.
  Future<AdResult> showRewardedAd({String? placement});

  /// Shows an interstitial ad. Resolves with [AdStatus.shown] (or skipped).
  Future<AdResult> showInterstitial({String? placement});

  /// Whether an ad is currently available to show for [placement].
  Future<bool> isAdAvailable({String? placement});
}
