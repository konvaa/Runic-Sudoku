import '../../core/profile/app_controller.dart';
import 'progression.dart';

/// Bridges the generic [AppController] (profile/persistence) with the
/// game-specific [Progression] rules. The UI listens to [AppController] for
/// rebuilds; this exposes campaign queries and the completion flow.
class ProgressionController {
  final AppController app;
  final Progression progression;

  ProgressionController({required this.app, required this.progression});

  // ---- Queries (pure functions of the completed set) ----------------------

  bool isLevelUnlocked(String levelId) =>
      progression.isLevelUnlocked(levelId, app.completedLevelIds);

  bool isChapterUnlocked(String chapterId) =>
      progression.isChapterUnlocked(chapterId, app.completedLevelIds);

  bool isCompleted(String levelId) => app.isCompleted(levelId);

  String? get nextLevelId => progression.nextLevelId(app.completedLevelIds);

  bool isNext(String levelId) => nextLevelId == levelId;

  int completedInChapter(ChapterMeta chapter) =>
      progression.completedInChapter(chapter, app.completedLevelIds);

  // ---- Mutations -----------------------------------------------------------

  /// Records a level completion. Daily completions update the streak only (via
  /// [AppController.onLevelCompleted]); they do NOT feed campaign progression, so
  /// the unlock re-derivation is skipped for them.
  Future<void> recordCompletion(
    String levelId, {
    bool isDaily = false,
    DateTime? date,
  }) async {
    await app.onLevelCompleted(levelId, isDaily: isDaily, date: date);
    if (!isDaily) await _sync(lastPlayed: levelId);
  }

  /// Remembers the most recently opened level (for a future "continue" entry).
  Future<void> markOpened(String levelId) => app.setLastPlayedLevel(levelId);

  /// Recomputes + persists the derived unlock sets from the current completed
  /// set. Call once at startup so a fresh profile starts with level 1 unlocked
  /// and any rule change re-derives cleanly.
  Future<void> ensureInitialized() => _sync();

  Future<void> _sync({String? lastPlayed}) {
    final completed = app.completedLevelIds;
    return app.recordProgression(
      unlockedLevels: progression.computeUnlockedLevels(completed),
      unlockedChapters: progression.computeUnlockedChapters(completed),
      chapterProgress: progression.chapterProgress(completed),
      lastPlayedLevelId: lastPlayed,
    );
  }
}
