import '../save/snapshot.dart';

/// App-wide player profile (Phase 0 §10). Persisted as a [Snapshot] under the
/// fixed key `app/profile`, so it reuses the existing
/// `SaveService.save(snapshot, trigger)` mechanism without any new storage code.
///
/// Mutable by design: a single instance is owned by `AppController`, mutated in
/// place, and re-saved. All dates are stored/compared at day granularity for
/// streak logic.
class PlayerProfile implements Snapshot {
  static const String gameIdValue = 'app';
  static const String levelIdValue = 'profile';

  int sessionsCount;
  int completedLevelsCount;
  Set<String> completedLevelIds;

  int interstitialShownLifetime;
  int rewardedShownLifetime;
  int removeAdsOfferShownCount;
  bool removeAdsPurchased;

  DateTime firstOpenTimestamp;
  DateTime? lastPlayedDate;

  /// Daily-challenge streak bookkeeping.
  DateTime? lastDailyCompletedDate;
  int dailyStreak;

  /// Frequency-capping counters (not part of the Phase 0 §10 list, but needed to
  /// implement the interstitial cadence and the offer trigger — see
  /// PHASE3_NOTES.md).
  int levelsSinceInterstitial;
  int interstitialsSinceLastOffer;

  // ---- Phase 3.5 campaign progression ----
  Set<String> unlockedLevelIds;
  Set<String> unlockedChapterIds;
  String? lastPlayedLevelId;
  Map<String, int> chapterProgress;

  /// Migration switch for future progression-model changes. Constant `1` for now
  /// (no migration logic — the field is just reserved).
  int progressionVersion;

  PlayerProfile({
    required this.firstOpenTimestamp,
    this.sessionsCount = 0,
    this.completedLevelsCount = 0,
    Set<String>? completedLevelIds,
    this.interstitialShownLifetime = 0,
    this.rewardedShownLifetime = 0,
    this.removeAdsOfferShownCount = 0,
    this.removeAdsPurchased = false,
    this.lastPlayedDate,
    this.lastDailyCompletedDate,
    this.dailyStreak = 0,
    this.levelsSinceInterstitial = 0,
    this.interstitialsSinceLastOffer = 0,
    Set<String>? unlockedLevelIds,
    Set<String>? unlockedChapterIds,
    this.lastPlayedLevelId,
    Map<String, int>? chapterProgress,
    this.progressionVersion = 1,
  })  : completedLevelIds = completedLevelIds ?? <String>{},
        unlockedLevelIds = unlockedLevelIds ?? <String>{},
        unlockedChapterIds = unlockedChapterIds ?? <String>{},
        chapterProgress = chapterProgress ?? <String, int>{};

  /// Spec alias for `completed_levels_count`.
  int get totalCompletedLevels => completedLevelsCount;

  @override
  String get gameId => gameIdValue;
  @override
  String get levelId => levelIdValue;
  @override
  String get saveKey => '$gameId/$levelId';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Map<String, dynamic> toJson() => {
        'game_id': gameId,
        'level_id': levelId,
        'sessions_count': sessionsCount,
        'completed_levels_count': completedLevelsCount,
        'completed_level_ids': completedLevelIds.toList()..sort(),
        'interstitial_shown_lifetime': interstitialShownLifetime,
        'rewarded_shown_lifetime': rewardedShownLifetime,
        'remove_ads_offer_shown_count': removeAdsOfferShownCount,
        'remove_ads_purchased': removeAdsPurchased,
        'first_open_timestamp': firstOpenTimestamp.toIso8601String(),
        'last_played_date':
            lastPlayedDate == null ? null : _dateKey(lastPlayedDate!),
        'last_daily_completed_date': lastDailyCompletedDate == null
            ? null
            : _dateKey(lastDailyCompletedDate!),
        'daily_streak': dailyStreak,
        'levels_since_interstitial': levelsSinceInterstitial,
        'interstitials_since_last_offer': interstitialsSinceLastOffer,
        'total_completed_levels': totalCompletedLevels,
        'unlocked_level_ids': unlockedLevelIds.toList()..sort(),
        'unlocked_chapter_ids': unlockedChapterIds.toList()..sort(),
        'last_played_level_id': lastPlayedLevelId,
        'chapter_progress': chapterProgress,
        'progression_version': progressionVersion,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic v) => v == null ? null : DateTime.parse(v as String);
    return PlayerProfile(
      firstOpenTimestamp:
          DateTime.parse(json['first_open_timestamp'] as String),
      sessionsCount: (json['sessions_count'] as num?)?.toInt() ?? 0,
      completedLevelsCount:
          (json['completed_levels_count'] as num?)?.toInt() ?? 0,
      completedLevelIds: {
        for (final id in (json['completed_level_ids'] as List? ?? const []))
          id as String,
      },
      interstitialShownLifetime:
          (json['interstitial_shown_lifetime'] as num?)?.toInt() ?? 0,
      rewardedShownLifetime:
          (json['rewarded_shown_lifetime'] as num?)?.toInt() ?? 0,
      removeAdsOfferShownCount:
          (json['remove_ads_offer_shown_count'] as num?)?.toInt() ?? 0,
      removeAdsPurchased: json['remove_ads_purchased'] as bool? ?? false,
      lastPlayedDate: date(json['last_played_date']),
      lastDailyCompletedDate: date(json['last_daily_completed_date']),
      dailyStreak: (json['daily_streak'] as num?)?.toInt() ?? 0,
      levelsSinceInterstitial:
          (json['levels_since_interstitial'] as num?)?.toInt() ?? 0,
      interstitialsSinceLastOffer:
          (json['interstitials_since_last_offer'] as num?)?.toInt() ?? 0,
      unlockedLevelIds: {
        for (final id in (json['unlocked_level_ids'] as List? ?? const []))
          id as String,
      },
      unlockedChapterIds: {
        for (final id in (json['unlocked_chapter_ids'] as List? ?? const []))
          id as String,
      },
      lastPlayedLevelId: json['last_played_level_id'] as String?,
      chapterProgress: {
        for (final e in (json['chapter_progress'] as Map? ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      progressionVersion: (json['progression_version'] as num?)?.toInt() ?? 1,
    );
  }
}
