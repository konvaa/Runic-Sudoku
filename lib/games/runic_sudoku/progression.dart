import 'level_pool.dart';

/// One campaign chapter (a difficulty band of the 6×6 pool).
class ChapterMeta {
  final String id; // 'chapter_1' …
  final int order; // 1-based
  final String displayName; // placeholder copy; final names chosen later
  final String difficultyLabel; // 'Quick' / 'Normal' / 'Tricky' / 'Deep'
  final List<String> levelIds; // ordered

  const ChapterMeta({
    required this.id,
    required this.order,
    required this.displayName,
    required this.difficultyLabel,
    required this.levelIds,
  });

  int get size => levelIds.length;
}

/// Static metadata for one campaign level (derived from the pool at runtime —
/// the pool JSON does not store chapter info; see PHASE35_NOTES.md).
class LevelMeta {
  final String levelId;
  final String chapterId;
  final int chapterOrder;
  final int levelOrder; // 1-based within the chapter
  final String difficultyLabel;
  final Duration estimatedSolveTime;
  final bool lockedByDefault;
  final String unlockRequirement; // human-readable

  const LevelMeta({
    required this.levelId,
    required this.chapterId,
    required this.chapterOrder,
    required this.levelOrder,
    required this.difficultyLabel,
    required this.estimatedSolveTime,
    required this.lockedByDefault,
    required this.unlockRequirement,
  });
}

/// Pure campaign progression rules over the 6×6 level pool.
///
/// Source of truth for unlock state is the player's *completed* set plus these
/// rules — everything here is a pure function of `completed`, so it is trivially
/// testable and cannot drift. (`PlayerProfile` also persists the derived unlocked
/// sets, recomputed via [computeUnlockedLevels]/[computeUnlockedChapters], to
/// satisfy the Phase 3.5 data-model fields.)
class Progression {
  final List<ChapterMeta> chapters;
  final Map<String, LevelMeta> levelsById;

  /// Fraction of a chapter that must be completed to unlock the next chapter.
  final double chapterUnlockFraction;

  const Progression._(
    this.chapters,
    this.levelsById,
    this.chapterUnlockFraction,
  );

  static const Map<String, String> _displayNames = {
    'Quick': 'Quick Runes',
    'Normal': 'Normal Seals',
    'Tricky': 'Tricky Glyphs',
    'Deep': 'Deep Chambers',
  };

  /// Builds chapters from the pool, one chapter per present difficulty label in
  /// [LevelPool.labelOrder].
  factory Progression.fromPool(
    LevelPool pool, {
    double chapterUnlockFraction = 0.5,
  }) {
    final chapters = <ChapterMeta>[];
    final levelsById = <String, LevelMeta>{};
    var order = 1;
    String? prevLabel;
    int prevThreshold = 0;

    for (final label in pool.presentLabels) {
      final group = pool.byLabel(label);
      final chapterId = 'chapter_$order';
      final ids = [for (final p in group) p.levelId];
      final threshold = (ids.length * chapterUnlockFraction).ceil();

      chapters.add(ChapterMeta(
        id: chapterId,
        order: order,
        displayName: _displayNames[label] ?? 'Chapter $order',
        difficultyLabel: label,
        levelIds: ids,
      ));

      for (var i = 0; i < group.length; i++) {
        final p = group[i];
        final firstOfChapter = i == 0;
        final firstOfAll = order == 1 && firstOfChapter;
        final String requirement;
        if (firstOfAll) {
          requirement = 'Available from the start';
        } else if (firstOfChapter) {
          requirement =
              'Complete $prevThreshold ${_displayNames[prevLabel] ?? prevLabel} levels';
        } else {
          requirement = 'Complete the previous level';
        }
        levelsById[p.levelId] = LevelMeta(
          levelId: p.levelId,
          chapterId: chapterId,
          chapterOrder: order,
          levelOrder: i + 1,
          difficultyLabel: label,
          estimatedSolveTime: p.estimatedSolveTime,
          lockedByDefault: !firstOfAll,
          unlockRequirement: requirement,
        );
      }

      prevLabel = label;
      prevThreshold = threshold;
      order++;
    }

    return Progression._(chapters, levelsById, chapterUnlockFraction);
  }

  ChapterMeta? chapterById(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  int thresholdFor(ChapterMeta chapter) =>
      (chapter.size * chapterUnlockFraction).ceil();

  int completedInChapter(ChapterMeta chapter, Set<String> completed) =>
      chapter.levelIds.where(completed.contains).length;

  /// Free Play (Phase 3.66) unlocks once the FIRST chapter (Quick Runes) is
  /// completed to its unlock threshold — i.e. the same condition that opens
  /// chapter 2. Pure function of [completed], so it can never drift.
  bool isFreePlayUnlocked(Set<String> completed) {
    if (chapters.isEmpty) return false;
    final first = chapters.first;
    return completedInChapter(first, completed) >= thresholdFor(first);
  }

  bool isChapterUnlocked(String chapterId, Set<String> completed) {
    final chapter = chapterById(chapterId);
    if (chapter == null) return false;
    if (chapter.order == 1) return true;
    final prev = chapters[chapter.order - 2];
    return completedInChapter(prev, completed) >= thresholdFor(prev);
  }

  bool isLevelUnlocked(String levelId, Set<String> completed) {
    if (completed.contains(levelId)) return true; // completed -> replayable
    final meta = levelsById[levelId];
    if (meta == null) return false;
    if (!isChapterUnlocked(meta.chapterId, completed)) return false;
    if (meta.levelOrder == 1) return true;
    final chapter = chapterById(meta.chapterId)!;
    final prevId = chapter.levelIds[meta.levelOrder - 2];
    return completed.contains(prevId);
  }

  Set<String> computeUnlockedLevels(Set<String> completed) {
    final out = <String>{};
    for (final chapter in chapters) {
      if (!isChapterUnlocked(chapter.id, completed)) continue;
      for (var i = 0; i < chapter.levelIds.length; i++) {
        if (i == 0 || completed.contains(chapter.levelIds[i - 1])) {
          out.add(chapter.levelIds[i]);
        }
      }
    }
    // Completed levels are always replayable, even if their chapter later locks.
    out.addAll(completed.where(levelsById.containsKey));
    return out;
  }

  Set<String> computeUnlockedChapters(Set<String> completed) => {
        for (final c in chapters)
          if (isChapterUnlocked(c.id, completed)) c.id,
      };

  Map<String, int> chapterProgress(Set<String> completed) => {
        for (final c in chapters) c.id: completedInChapter(c, completed),
      };

  /// The next level to play: first unlocked-but-incomplete level in campaign
  /// order, or null if everything is done.
  String? nextLevelId(Set<String> completed) {
    for (final chapter in chapters) {
      if (!isChapterUnlocked(chapter.id, completed)) continue;
      for (final id in chapter.levelIds) {
        if (!completed.contains(id) && isLevelUnlocked(id, completed)) return id;
      }
    }
    return null;
  }
}
