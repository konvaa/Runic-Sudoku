import 'board_config.dart';
import 'level_pool.dart';
import 'manual_puzzle.dart';

/// Static campaign structure contract (Chapter 2 architecture, Batch 2).
///
/// Introduces the Chapter/Tier/Registry data model from the approved design
/// (docs/chapter2_data_model_design_result.md §B) and models the existing 100
/// Chapter 1 levels through it. In THIS batch the registry is a **parallel,
/// testable implementation** beside the live [Progression] model: nothing in
/// `main.dart`, `ProgressionController`, `AppController`, or persistence uses
/// it yet. Behavioral parity with the live model is proven by the differential
/// test (test/chapter2_static_contract_differential_test.dart); the live
/// cutover is a later, separately reviewed batch.
///
/// Identity-axis separation (design "eight axes" rule): `tierId` (stable
/// identity), `difficultyLabel` (generation/calibration profile), and
/// `displayName` (fantasy UI text) are three independent, separately stored
/// axes — none is derived from another, and none is derived from list
/// position. Level identity is the explicit `levelId` frozen in Batch 1;
/// chapter/tier membership is read from the level's stored `chapterId`/
/// `tierId`, never parsed out of the id string.
///
/// NOTE on display names: the design ultimately wants `displayNameKey`
/// (localization keys). The app has no l10n infrastructure yet, so this batch
/// stores the exact strings today's UI shows (no new names introduced); the
/// key indirection arrives with localization, touching only this data.

// ---------------------------------------------------------------------------
// Unlock policies (target shape; NO frozen thresholds in this batch)
// ---------------------------------------------------------------------------

enum ChapterUnlockPolicyType {
  /// The chapter is open from the start (Chapter 1).
  initiallyUnlocked,

  /// The chapter opens after N core-level completions in a prerequisite
  /// chapter. No shipped instance uses this yet — the real Chapter 2 gate
  /// (decision G1) belongs to the Chapter 2 content batch.
  completedCoreCountInChapter,
}

/// When a whole roadmap chapter opens.
class ChapterUnlockPolicy {
  final ChapterUnlockPolicyType type;

  /// Explicit prerequisite chapter id — never an array position.
  final String? prerequisiteChapterId;

  /// Absolute completed-core-level count required in the prerequisite chapter
  /// (target shape for the future frozen gate). Null for
  /// [ChapterUnlockPolicyType.initiallyUnlocked]. No shipped instance carries
  /// a value in this batch; a `completedCoreCountInChapter` policy with a null
  /// count never unlocks (fail-closed).
  final int? coreLevelsRequired;

  /// Bumped only to intentionally change the gate (design §B).
  final int policyVersion;

  const ChapterUnlockPolicy.initiallyUnlocked({this.policyVersion = 1})
      : type = ChapterUnlockPolicyType.initiallyUnlocked,
        prerequisiteChapterId = null,
        coreLevelsRequired = null;

  const ChapterUnlockPolicy.completedCoreCountInChapter({
    required String this.prerequisiteChapterId,
    required int this.coreLevelsRequired,
    this.policyVersion = 1,
  }) : type = ChapterUnlockPolicyType.completedCoreCountInChapter;
}

enum TierUnlockPolicyType {
  /// The tier is open as soon as its chapter is (first tier of a chapter).
  initiallyUnlocked,

  /// The tier opens after enough completions in an explicit prerequisite tier.
  completedCountInTier,

  /// The tier is unreachable regardless of any other condition (future
  /// Expert-while-gated state; no Chapter 1 tier uses it).
  disabled,
}

/// When a tier opens inside its chapter.
///
/// HARD BOUNDARY (this batch): the policy deliberately stores **no numeric
/// threshold**. A `completedCountInTier` gate is evaluated LIVE as
/// `ceil(currentPrerequisiteTierSize × unlockFraction)` — exactly today's
/// behaviour (see [RegistryProgression] in registry_progression.dart), so the
/// live-size relock hazard (design must-close #5/#6) intentionally still
/// exists, for parity.
/// TODO(frozen-thresholds batch): add `completedLevelsRequired` as a FROZEN
/// absolute snapshot (+ policyVersion bump semantics) and stop reading live
/// tier size. That freeze is explicitly the next, separately reviewed batch.
class TierUnlockPolicy {
  final TierUnlockPolicyType type;

  /// Explicit prerequisite tier id within the same chapter — never
  /// `chapters[order - 2]`/array position.
  final String? prerequisiteTierId;

  /// Bumped only to intentionally change the gate (design §B).
  final int policyVersion;

  const TierUnlockPolicy.initiallyUnlocked({this.policyVersion = 1})
      : type = TierUnlockPolicyType.initiallyUnlocked,
        prerequisiteTierId = null;

  const TierUnlockPolicy.completedCountInTier({
    required String this.prerequisiteTierId,
    this.policyVersion = 1,
  }) : type = TierUnlockPolicyType.completedCountInTier;

  const TierUnlockPolicy.disabled({this.policyVersion = 1})
      : type = TierUnlockPolicyType.disabled,
        prerequisiteTierId = null;
}

// ---------------------------------------------------------------------------
// Static definitions
// ---------------------------------------------------------------------------

/// One bundled campaign level, with its identity axes stored explicitly.
class LevelDefinition {
  /// Opaque, durable id (Chapter 1: the `rs_NNN` ids frozen in Batch 1).
  final String levelId;

  /// Stored chapter membership — never parsed from [levelId].
  final String chapterId;

  /// Stored tier membership — never parsed from [levelId] or derived from
  /// [difficultyLabel]/list position.
  final String tierId;

  /// 1-based authored sequence WITHIN the tier (order, not identity).
  final int levelOrder;

  /// The puzzle payload — the same immutable [ManualPuzzle] the live model
  /// uses (shared domain data type; see the differential test's independence
  /// note).
  final ManualPuzzle puzzle;

  const LevelDefinition({
    required this.levelId,
    required this.chapterId,
    required this.tierId,
    required this.levelOrder,
    required this.puzzle,
  });

  String get difficultyLabel => puzzle.difficultyLabel;
  Duration get estimatedSolveTime => puzzle.estimatedSolveTime;
}

/// A tier: an ordered run of levels inside a chapter.
class TierDefinition {
  final String tierId;

  /// Fantasy UI name — independent axis, identical to today's UI strings.
  final String displayName;

  /// Generation/calibration profile — independent axis (kept as the pool's
  /// string token, matching existing code shape).
  final String difficultyLabel;

  final BoardConfig boardConfig;

  /// Core tiers count toward chapter completion/unlock denominators; the
  /// future optional Expert tier will not (design G5/G6).
  final bool countsTowardProgress;
  final bool isOptionalExpert;

  /// Ordered by [LevelDefinition.levelOrder] (1..size).
  final List<LevelDefinition> levels;

  final TierUnlockPolicy unlockPolicy;

  const TierDefinition({
    required this.tierId,
    required this.displayName,
    required this.difficultyLabel,
    required this.boardConfig,
    required this.levels,
    required this.unlockPolicy,
    this.countsTowardProgress = true,
    this.isOptionalExpert = false,
  });

  int get size => levels.length;

  List<String> get levelIds => [for (final l in levels) l.levelId];
}

/// A roadmap chapter (board/level-set), e.g. `c1` (6×6), future `c2` (9×9).
class ChapterDefinition {
  final String chapterId;

  /// Display/sequence only — never used for unlock prerequisites (those are
  /// explicit ids in the policies).
  final int order;

  final BoardConfig coreBoardConfig;

  /// Tiers in display order.
  final List<TierDefinition> tiers;

  final ChapterUnlockPolicy unlockPolicy;

  const ChapterDefinition({
    required this.chapterId,
    required this.order,
    required this.coreBoardConfig,
    required this.tiers,
    required this.unlockPolicy,
  });

  TierDefinition? tierById(String tierId) {
    for (final t in tiers) {
      if (t.tierId == tierId) return t;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

/// The static campaign structure: all chapters + a level-id index across them.
///
/// Progression queries over this registry live in [RegistryProgression]
/// (registry_progression.dart); no query reads array position as identity.
class CampaignRegistry {
  final List<ChapterDefinition> chapters;

  /// Union across all chapter pools. Built with a duplicate-id guard: a level
  /// id may exist exactly once across the whole campaign (released-id
  /// immutability, design §C-bis).
  final Map<String, LevelDefinition> levelsById;

  CampaignRegistry(this.chapters) : levelsById = _index(chapters);

  static Map<String, LevelDefinition> _index(
      List<ChapterDefinition> chapters) {
    final out = <String, LevelDefinition>{};
    for (final c in chapters) {
      for (final t in c.tiers) {
        for (final l in t.levels) {
          if (out.containsKey(l.levelId)) {
            throw ArgumentError(
                'Duplicate levelId "${l.levelId}" in campaign registry');
          }
          out[l.levelId] = l;
        }
      }
    }
    return out;
  }

  ChapterDefinition? chapterById(String chapterId) {
    for (final c in chapters) {
      if (c.chapterId == chapterId) return c;
    }
    return null;
  }

  ChapterDefinition? chapterOf(String levelId) {
    final l = levelsById[levelId];
    return l == null ? null : chapterById(l.chapterId);
  }

  TierDefinition? tierOf(String levelId) {
    final l = levelsById[levelId];
    return l == null ? null : chapterOf(levelId)?.tierById(l.tierId);
  }

  // ---- Chapter 1 -----------------------------------------------------------

  /// Stable tier identity for each Chapter 1 difficulty band (decision G2:
  /// today's band-"chapters" become c1's tiers, preserved exactly). An
  /// explicit authored mapping — NOT string-derivation from the label (the
  /// axes stay independent; this table is construction data).
  static const Map<String, String> _c1TierIdForLabel = {
    'Quick': 'quick',
    'Normal': 'normal',
    'Tricky': 'tricky',
    'Deep': 'deep',
  };

  /// Exactly the display names today's UI shows (Progression._displayNames).
  /// No new fantasy names in this batch.
  static const Map<String, String> _c1TierDisplayName = {
    'quick': 'Quick Runes',
    'normal': 'Normal Seals',
    'tricky': 'Tricky Glyphs',
    'deep': 'Deep Chambers',
  };

  /// Builds the Chapter 1 registry from the shipped pool: one tier per present
  /// difficulty label in [LevelPool.labelOrder] (mirroring how the live
  /// `Progression.fromPool` builds its band-chapters), levels in pool order,
  /// first tier initially unlocked, each later tier gated on the explicit id
  /// of the tier before it. No thresholds are stored (see [TierUnlockPolicy]).
  factory CampaignRegistry.chapter1FromPool(LevelPool pool) {
    // Complete-coverage guard: every pool level must map into a Chapter 1
    // tier. `pool.presentLabels` silently filters to the known label order, so
    // without this check a level with an unmapped label would be silently
    // DROPPED from the registry (present in the pool, absent from progression)
    // — fail loudly instead.
    for (final puzzle in pool.levels) {
      if (!_c1TierIdForLabel.containsKey(puzzle.difficultyLabel)) {
        throw ArgumentError(
            'No Chapter 1 tier mapping for difficulty label '
            '"${puzzle.difficultyLabel}" (level "${puzzle.levelId}")');
      }
    }

    final tiers = <TierDefinition>[];
    String? prevTierId;
    for (final label in pool.presentLabels) {
      final tierId = _c1TierIdForLabel[label]!; // every label validated above
      final group = pool.byLabel(label);
      final levels = <LevelDefinition>[
        for (var i = 0; i < group.length; i++)
          LevelDefinition(
            levelId: group[i].levelId,
            chapterId: 'c1',
            tierId: tierId,
            levelOrder: i + 1,
            puzzle: group[i],
          ),
      ];
      tiers.add(TierDefinition(
        tierId: tierId,
        displayName: _c1TierDisplayName[tierId]!,
        difficultyLabel: label,
        boardConfig: BoardConfig.sixBySix,
        levels: levels,
        unlockPolicy: prevTierId == null
            ? const TierUnlockPolicy.initiallyUnlocked()
            : TierUnlockPolicy.completedCountInTier(
                prerequisiteTierId: prevTierId),
      ));
      prevTierId = tierId;
    }

    return CampaignRegistry([
      ChapterDefinition(
        chapterId: 'c1',
        order: 1,
        coreBoardConfig: BoardConfig.sixBySix,
        tiers: tiers,
        unlockPolicy: const ChapterUnlockPolicy.initiallyUnlocked(),
      ),
    ]);
  }
}
