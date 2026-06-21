import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';
import '../monetization/monetization_policy.dart';
import '../save/save_service.dart';
import '../save/save_trigger_type.dart';
import 'player_profile.dart';

/// Owns the [PlayerProfile] and applies Phase 0 §10 bookkeeping: sessions,
/// completion counts, daily streak, monetization counters. Persists the profile
/// through the existing `SaveService.save(snapshot, trigger)` and logs analytics.
///
/// It returns monetization *decisions* (via [MonetizationPolicy]) but performs no
/// ad calls or dialogs — that stays in the UI, which records results back here.
///
/// Some profile-only events (session start, offer shown) have no dedicated Phase
/// 0 trigger; they persist with [SaveTriggerType.appPause] as a generic flush —
/// see PHASE3_NOTES.md "Specification ambiguities".
class AppController extends ChangeNotifier {
  final PlayerProfile profile;
  final SaveService saveService;
  final AnalyticsService analytics;

  DateTime _sessionStart = DateTime.now();

  AppController({
    required this.profile,
    required this.saveService,
    required this.analytics,
  });

  /// Loads the persisted profile or creates a fresh one (first launch).
  static Future<AppController> load({
    required SaveService saveService,
    required AnalyticsService analytics,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final raw = await saveService.load('${PlayerProfile.gameIdValue}/'
        '${PlayerProfile.levelIdValue}');
    final profile = raw != null
        ? PlayerProfile.fromJson(raw)
        : PlayerProfile(firstOpenTimestamp: ts);
    return AppController(
      profile: profile,
      saveService: saveService,
      analytics: analytics,
    );
  }

  // ---- Read-only view ------------------------------------------------------

  bool get removeAdsPurchased => profile.removeAdsPurchased;
  Set<String> get completedLevelIds => Set.unmodifiable(profile.completedLevelIds);
  bool isCompleted(String levelId) =>
      profile.completedLevelIds.contains(levelId);
  int get dailyStreak => profile.dailyStreak;
  Duration get sessionDuration => DateTime.now().difference(_sessionStart);

  // Free Play stats (Phase 3.66).
  int get freePlaysCompleted => profile.freePlaysCompleted;
  int get freePlaysCurrentStreak => profile.freePlaysCurrentStreak;
  Map<String, int> get freePlaysBestTimes =>
      Map.unmodifiable(profile.freePlaysBestTimes);

  /// Best Free Play solve time (whole seconds) for [difficultyLabel], or null.
  int? bestFreePlayTime(String difficultyLabel) =>
      profile.freePlaysBestTimes[difficultyLabel];

  /// Deep Free Play puzzle ids already shown to the player.
  Set<String> get deepUsedIds => Set.unmodifiable(profile.deepUsedIds);

  /// Marks a Deep Free Play puzzle as seen (persisted; no listener notify — no
  /// UI depends on this set).
  Future<void> markDeepUsed(String puzzleId) async {
    if (!profile.deepUsedIds.add(puzzleId)) return;
    await _save(SaveTriggerType.appPause);
  }

  // Campaign progression (the game layer computes these; this just stores them).
  Set<String> get unlockedLevelIds =>
      Set.unmodifiable(profile.unlockedLevelIds);
  Set<String> get unlockedChapterIds =>
      Set.unmodifiable(profile.unlockedChapterIds);
  String? get lastPlayedLevelId => profile.lastPlayedLevelId;

  // ---- Session -------------------------------------------------------------

  /// Call once at app start.
  Future<void> onSessionStart({DateTime? now}) async {
    _sessionStart = now ?? DateTime.now();
    profile.sessionsCount++;
    await _save(SaveTriggerType.appPause);
    await analytics.log('session_start', {
      'sessions_count': profile.sessionsCount,
    });
    notifyListeners();
  }

  // ---- Level completion + daily streak ------------------------------------

  Future<void> onLevelCompleted(
    String levelId, {
    bool isDaily = false,
    DateTime? date,
  }) async {
    final today = _dateOnly(date ?? DateTime.now());

    // Frequency cadence advances on every completion (incl. daily + replays).
    profile.levelsSinceInterstitial++;
    profile.lastPlayedDate = today;

    if (isDaily) {
      // Daily is a separate system: it must NOT count toward campaign
      // progression (completed_level_ids / completed_levels_count). It only
      // advances the daily streak. See PHASE35_NOTES.md (Phase 3.5 bugfix).
      _advanceDailyStreak(today);
    } else {
      final firstTime = profile.completedLevelIds.add(levelId);
      if (firstTime) profile.completedLevelsCount++;
    }

    await _save(SaveTriggerType.levelComplete);
    await analytics.log('profile_level_completed', {
      'level_id': levelId,
      'is_daily': isDaily,
      'completed_levels_count': profile.completedLevelsCount,
      'daily_streak': profile.dailyStreak,
    });
    notifyListeners();
  }

  void _advanceDailyStreak(DateTime today) {
    final last = profile.lastDailyCompletedDate;
    if (last == null) {
      profile.dailyStreak = 1;
    } else {
      final diff = _dayNumber(today) - _dayNumber(last);
      if (diff == 0) {
        // already counted today; no change
      } else if (diff == 1) {
        profile.dailyStreak++;
      } else {
        profile.dailyStreak = 1; // a day was missed -> streak restarts
      }
    }
    profile.lastDailyCompletedDate = today;
  }

  /// Whole-day ordinal (DST-safe) for streak arithmetic.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  // ---- Free Play (Phase 3.66) ---------------------------------------------

  /// Records a solved Free Play puzzle. Deliberately INDEPENDENT of campaign and
  /// daily: it never touches `completed_level_ids`, the campaign count, or the
  /// daily streak. It updates the Free Play stats and advances the shared
  /// interstitial cadence (so ads fire at the same every-3rd-completion rate).
  Future<void> onFreePlayCompleted(
    String difficultyLabel,
    Duration solveTime, {
    DateTime? date,
  }) async {
    profile.freePlaysCompleted++;
    profile.freePlaysCurrentStreak++;

    final secs = solveTime.inSeconds;
    final prev = profile.freePlaysBestTimes[difficultyLabel];
    if (prev == null || secs < prev) {
      profile.freePlaysBestTimes[difficultyLabel] = secs;
    }

    profile.levelsSinceInterstitial++; // same ad cadence as campaign levels
    profile.lastPlayedDate = _dateOnly(date ?? DateTime.now());

    await _save(SaveTriggerType.levelComplete);
    await analytics.log('free_play_completed', {
      'difficulty': difficultyLabel,
      'solve_seconds': secs,
      'free_plays_completed': profile.freePlaysCompleted,
      'streak': profile.freePlaysCurrentStreak,
    });
    notifyListeners();
  }

  /// Resets the consecutive Free Play streak (called when the player leaves the
  /// Free Play flow / starts a new session).
  Future<void> resetFreePlayStreak() async {
    if (profile.freePlaysCurrentStreak == 0) return;
    profile.freePlaysCurrentStreak = 0;
    await _save(SaveTriggerType.appPause);
    notifyListeners();
  }

  // ---- Monetization decisions + recording ---------------------------------

  bool shouldShowInterstitial() =>
      MonetizationPolicy.shouldShowInterstitial(profile);

  Future<void> markInterstitialShown() async {
    profile.interstitialShownLifetime++;
    profile.interstitialsSinceLastOffer++;
    profile.levelsSinceInterstitial = 0;
    await _save(SaveTriggerType.interstitialShown);
    await analytics.log('interstitial_shown', {
      'interstitial_shown_lifetime': profile.interstitialShownLifetime,
    });
    notifyListeners();
  }

  bool shouldShowRemoveAdsOffer() =>
      MonetizationPolicy.shouldShowRemoveAdsOffer(profile, sessionDuration);

  Future<void> markRemoveAdsOfferShown() async {
    profile.removeAdsOfferShownCount++;
    profile.interstitialsSinceLastOffer = 0;
    await _save(SaveTriggerType.appPause); // no dedicated trigger
    await analytics.log('remove_ads_offer_shown', {
      'remove_ads_offer_shown_count': profile.removeAdsOfferShownCount,
    });
    notifyListeners();
  }

  Future<void> markRewardedShown() async {
    profile.rewardedShownLifetime++;
    await _save(SaveTriggerType.rewardedAdCompleted);
    await analytics.log('rewarded_shown', {
      'rewarded_shown_lifetime': profile.rewardedShownLifetime,
    });
    notifyListeners();
  }

  Future<void> setRemoveAdsPurchased() async {
    if (profile.removeAdsPurchased) return;
    profile.removeAdsPurchased = true;
    await _save(SaveTriggerType.purchaseCompleted);
    await analytics.log('remove_ads_purchased', const {});
    notifyListeners();
  }

  // ---- Campaign progression (Phase 3.5) -----------------------------------

  /// Stores the derived unlock state (computed by the game's `Progression`). The
  /// game layer owns the rules; App Core only persists generic id sets.
  Future<void> recordProgression({
    required Set<String> unlockedLevels,
    required Set<String> unlockedChapters,
    required Map<String, int> chapterProgress,
    String? lastPlayedLevelId,
  }) async {
    profile.unlockedLevelIds = unlockedLevels;
    profile.unlockedChapterIds = unlockedChapters;
    profile.chapterProgress = chapterProgress;
    if (lastPlayedLevelId != null) {
      profile.lastPlayedLevelId = lastPlayedLevelId;
    }
    await _save(SaveTriggerType.appPause);
    notifyListeners();
  }

  Future<void> setLastPlayedLevel(String levelId) async {
    if (profile.lastPlayedLevelId == levelId) return;
    profile.lastPlayedLevelId = levelId;
    await _save(SaveTriggerType.appPause);
    notifyListeners();
  }

  // ---- Persistence ---------------------------------------------------------

  Future<void> _save(SaveTriggerType trigger) =>
      saveService.save(profile, trigger);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
