import 'chapter_registry.dart';

/// Registry-driven campaign progression — the parallel counterpart of the live
/// `Progression` model, operating over [CampaignRegistry] (Batch 2).
///
/// NOT wired into the live app: `main.dart`, `ProgressionController`,
/// `AppController`, and persistence still use the legacy `Progression`. This
/// evaluator exists to be proven behaviourally identical for Chapter 1 by the
/// differential test (test/chapter2_static_contract_differential_test.dart)
/// before any cutover, which is a later, separately reviewed batch.
///
/// INDEPENDENCE: this class re-implements the progression semantics from
/// scratch over the registry structures. It never calls the legacy
/// `Progression` methods (`computeUnlockedLevels`, `isChapterUnlocked`, …) —
/// that independence is what makes the differential test meaningful. The only
/// things shared with the legacy side are immutable domain data
/// (`ManualPuzzle` payloads inside [LevelDefinition]) and the standard
/// library.
///
/// Legacy edge behaviours are intentionally reproduced exactly:
/// * an id present in `completed` is "unlocked" (replayable) even if the
///   registry does not know it — but `computeUnlockedLevels` only ever emits
///   ids the registry knows;
/// * progress counts pure set-membership per tier, so unknown ids contribute
///   nothing and a tier's count can exceed its unlock requirement;
/// * every query is a pure function of the completed-id set.
class RegistryProgression {
  final CampaignRegistry registry;

  /// Live unlock fraction — the same role (and default) as the legacy
  /// `chapterUnlockFraction`. A `completedCountInTier` gate requires
  /// `ceil(currentPrerequisiteTierSize × unlockFraction)` completions,
  /// computed at evaluation time from the registry's CURRENT tier size.
  /// TODO(frozen-thresholds batch): replace this live computation with frozen
  /// absolute per-policy counts (`completedLevelsRequired` + policyVersion);
  /// deliberately NOT done in this batch.
  final double unlockFraction;

  const RegistryProgression(this.registry, {this.unlockFraction = 0.5});

  // ---- Progress counting ---------------------------------------------------

  /// Completed levels inside [tier] (set membership only).
  int completedInTier(TierDefinition tier, Set<String> completed) {
    var n = 0;
    for (final l in tier.levels) {
      if (completed.contains(l.levelId)) n++;
    }
    return n;
  }

  /// The live-computed unlock requirement derived from a prerequisite tier:
  /// `ceil(size × unlockFraction)`. Independently implemented; mathematically
  /// identical to today's legacy `thresholdFor`.
  int requiredFromPrerequisite(TierDefinition prerequisite) =>
      (prerequisite.size * unlockFraction).ceil();

  // ---- Unlock queries ------------------------------------------------------

  bool isChapterUnlocked(String chapterId, Set<String> completed) {
    final chapter = registry.chapterById(chapterId);
    if (chapter == null) return false;
    final policy = chapter.unlockPolicy;
    switch (policy.type) {
      case ChapterUnlockPolicyType.initiallyUnlocked:
        return true;
      case ChapterUnlockPolicyType.completedCoreCountInChapter:
        final prereq = policy.prerequisiteChapterId == null
            ? null
            : registry.chapterById(policy.prerequisiteChapterId!);
        final required = policy.coreLevelsRequired;
        if (prereq == null || required == null) return false; // fail closed
        var done = 0;
        for (final tier in prereq.tiers) {
          if (!tier.countsTowardProgress) continue; // Expert never counts
          done += completedInTier(tier, completed);
        }
        return done >= required;
    }
  }

  bool isTierUnlocked(
      String chapterId, String tierId, Set<String> completed) {
    final chapter = registry.chapterById(chapterId);
    final tier = chapter?.tierById(tierId);
    if (chapter == null || tier == null) return false;
    if (!isChapterUnlocked(chapterId, completed)) return false;
    final policy = tier.unlockPolicy;
    switch (policy.type) {
      case TierUnlockPolicyType.initiallyUnlocked:
        return true;
      case TierUnlockPolicyType.disabled:
        return false;
      case TierUnlockPolicyType.completedCountInTier:
        final prereq = policy.prerequisiteTierId == null
            ? null
            : chapter.tierById(policy.prerequisiteTierId!);
        if (prereq == null) return false; // fail closed
        return completedInTier(prereq, completed) >=
            requiredFromPrerequisite(prereq);
    }
  }

  bool isLevelUnlocked(String levelId, Set<String> completed) {
    // Completed -> replayable, even if the id is unknown to the registry
    // (exact legacy behaviour).
    if (completed.contains(levelId)) return true;
    final level = registry.levelsById[levelId];
    if (level == null) return false;
    if (!isTierUnlocked(level.chapterId, level.tierId, completed)) {
      return false;
    }
    if (level.levelOrder == 1) return true;
    final tier = registry.tierOf(levelId)!;
    final prevId = tier.levels[level.levelOrder - 2].levelId;
    return completed.contains(prevId);
  }

  // ---- Derived sets --------------------------------------------------------

  Set<String> computeUnlockedLevels(Set<String> completed) {
    final out = <String>{};
    for (final chapter in registry.chapters) {
      for (final tier in chapter.tiers) {
        if (!isTierUnlocked(chapter.chapterId, tier.tierId, completed)) {
          continue;
        }
        for (var i = 0; i < tier.levels.length; i++) {
          if (i == 0 || completed.contains(tier.levels[i - 1].levelId)) {
            out.add(tier.levels[i].levelId);
          }
        }
      }
    }
    // Completed levels are always replayable, even if their tier later locks.
    out.addAll(completed.where(registry.levelsById.containsKey));
    return out;
  }

  /// Unlocked tiers as `chapterId/tierId` composite keys (in-memory query
  /// result only — the new identifiers are never persisted in this batch).
  Set<String> computeUnlockedTiers(Set<String> completed) => {
        for (final c in registry.chapters)
          for (final t in c.tiers)
            if (isTierUnlocked(c.chapterId, t.tierId, completed))
              '${c.chapterId}/${t.tierId}',
      };

  /// Completed count per tier, keyed `chapterId/tierId` (all tiers, locked
  /// included — mirroring the legacy chapterProgress shape).
  Map<String, int> tierProgress(Set<String> completed) => {
        for (final c in registry.chapters)
          for (final t in c.tiers)
            '${c.chapterId}/${t.tierId}': completedInTier(t, completed),
      };

  /// The next level to play: first unlocked-but-incomplete level in campaign
  /// order (chapters in order, tiers in order, levels in order), or null.
  String? nextLevelId(Set<String> completed) {
    for (final chapter in registry.chapters) {
      for (final tier in chapter.tiers) {
        if (!isTierUnlocked(chapter.chapterId, tier.tierId, completed)) {
          continue;
        }
        for (final level in tier.levels) {
          if (!completed.contains(level.levelId) &&
              isLevelUnlocked(level.levelId, completed)) {
            return level.levelId;
          }
        }
      }
    }
    return null;
  }

  /// Free Play opens once the FIRST tier of the FIRST chapter reaches its
  /// live-computed unlock threshold — the same condition that opens the second
  /// tier today (legacy `isFreePlayUnlocked` semantics).
  bool isFreePlayUnlocked(Set<String> completed) {
    if (registry.chapters.isEmpty) return false;
    final chapter = registry.chapters.first;
    if (chapter.tiers.isEmpty) return false;
    final first = chapter.tiers.first;
    return completedInTier(first, completed) >=
        requiredFromPrerequisite(first);
  }
}
