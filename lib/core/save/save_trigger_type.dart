/// Why a snapshot save was requested.
///
/// The save system performs a *complete snapshot save* on every trigger; the
/// trigger type is metadata (useful for analytics, debugging, and deciding
/// whether to also flush to durable storage immediately).
enum SaveTriggerType {
  levelStart,
  placementComplete,
  notesChanged,
  hintUsed,
  mistakeChecked,
  levelComplete,
  appPause,
  rewardedAdCompleted,
  interstitialShown,
  purchaseCompleted;

  /// Stable wire name used in logs/serialization (snake_case, matches Phase 0).
  String get wireName {
    switch (this) {
      case SaveTriggerType.levelStart:
        return 'level_start';
      case SaveTriggerType.placementComplete:
        return 'placement_complete';
      case SaveTriggerType.notesChanged:
        return 'notes_changed';
      case SaveTriggerType.hintUsed:
        return 'hint_used';
      case SaveTriggerType.mistakeChecked:
        return 'mistake_checked';
      case SaveTriggerType.levelComplete:
        return 'level_complete';
      case SaveTriggerType.appPause:
        return 'app_pause';
      case SaveTriggerType.rewardedAdCompleted:
        return 'rewarded_ad_completed';
      case SaveTriggerType.interstitialShown:
        return 'interstitial_shown';
      case SaveTriggerType.purchaseCompleted:
        return 'purchase_completed';
    }
  }
}
