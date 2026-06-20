import '../profile/player_profile.dart';

/// Pure monetization decision logic (Phase 0 §10 wiring). No UI, no SDK — it only
/// reads a [PlayerProfile] (+ current session duration) and returns whether the
/// app *should* show an interstitial or a remove-ads offer. The UI performs the
/// actual ad call / dialog and then records the result back on the profile.
///
/// Kept separate from `AppController` so the rules are unit-testable without a
/// widget tree (an explicit requirement of the Phase 3 brief).
///
/// All thresholds are placeholder defaults documented in PHASE3_NOTES.md.
class MonetizationPolicy {
  const MonetizationPolicy._();

  /// Show an interstitial at most once per this many level completions.
  static const int interstitialEveryNLevels = 3;

  /// First remove-ads offer after at least this many completed levels...
  static const int offerMinCompletedLevels = 5;

  /// ...OR at least this much time played in the session.
  static const Duration offerMinSessionDuration = Duration(minutes: 10);

  /// Only offer once at least this many interstitials have been shown since the
  /// last offer (the Phase 0 "after 2–3 interstitials" condition).
  static const int offerMinInterstitialsSinceOffer = 2;

  /// Never nag more than this many times over the app's lifetime.
  static const int maxOffersLifetime = 3;

  /// Whether to show an interstitial now (called on a level-complete transition,
  /// never mid-puzzle). Suppressed entirely once ads are removed.
  static bool shouldShowInterstitial(PlayerProfile p) =>
      !p.removeAdsPurchased &&
      p.levelsSinceInterstitial >= interstitialEveryNLevels;

  /// Whether to surface the remove-ads offer now.
  static bool shouldShowRemoveAdsOffer(
    PlayerProfile p,
    Duration sessionDuration,
  ) {
    if (p.removeAdsPurchased) return false;
    if (p.removeAdsOfferShownCount >= maxOffersLifetime) return false;
    if (p.interstitialsSinceLastOffer < offerMinInterstitialsSinceOffer) {
      return false;
    }
    return p.completedLevelsCount >= offerMinCompletedLevels ||
        sessionDuration >= offerMinSessionDuration;
  }
}
