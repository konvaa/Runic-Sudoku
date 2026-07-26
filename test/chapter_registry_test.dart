// Unit tests for the static campaign contract (Batch 2): registry
// construction from the shipped Chapter 1 pool, lookup surfaces, identity-axis
// separation, construction guards, and policy evaluation over SYNTHETIC data
// (the synthetic thresholds below are arbitrary test values exercising the
// target policy shape — no shipped frozen threshold exists in this batch).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/chapter_registry.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/registry_progression.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

ManualPuzzle _puzzle(String id, String label) => ManualPuzzle(
      levelId: id,
      seed: 0,
      gridSize: const GridDimensions(rows: 1, cols: 1),
      boxShape: const BoxShape(rows: 1, cols: 1),
      solutionGrid: const [
        [1]
      ],
      givenCells: const [
        [0]
      ],
      difficultyLabel: label,
      estimatedSolveTime: const Duration(minutes: 1),
    );

LevelDefinition _level(String id, String chapterId, String tierId, int order,
        {String label = 'Quick'}) =>
    LevelDefinition(
      levelId: id,
      chapterId: chapterId,
      tierId: tierId,
      levelOrder: order,
      puzzle: _puzzle(id, label),
    );

TierDefinition _tier(
  String chapterId,
  String tierId,
  List<String> levelIds,
  TierUnlockPolicy policy, {
  bool countsTowardProgress = true,
  bool isOptionalExpert = false,
}) =>
    TierDefinition(
      tierId: tierId,
      displayName: 'Test $tierId',
      difficultyLabel: 'Quick',
      boardConfig: BoardConfig.sixBySix,
      countsTowardProgress: countsTowardProgress,
      isOptionalExpert: isOptionalExpert,
      levels: [
        for (var i = 0; i < levelIds.length; i++)
          _level(levelIds[i], chapterId, tierId, i + 1),
      ],
      unlockPolicy: policy,
    );

void main() {
  group('Chapter 1 registry built from the shipped pool', () {
    final pool = LevelPool.fromJsonString(
        File(LevelPool.assetPath).readAsStringSync());
    final registry = CampaignRegistry.chapter1FromPool(pool);
    final c1 = registry.chapters.single;

    test('one chapter c1, initially unlocked, 6x6 board, ordered tiers', () {
      expect(c1.chapterId, 'c1');
      expect(c1.order, 1);
      expect(c1.coreBoardConfig, BoardConfig.sixBySix);
      expect(c1.unlockPolicy.type, ChapterUnlockPolicyType.initiallyUnlocked);
      expect([for (final t in c1.tiers) t.tierId],
          ['quick', 'normal', 'tricky', 'deep']);
      expect([for (final t in c1.tiers) t.size], [20, 30, 30, 20]);
      for (final t in c1.tiers) {
        expect(t.countsTowardProgress, isTrue);
        expect(t.isOptionalExpert, isFalse);
        expect(t.boardConfig, BoardConfig.sixBySix);
      }
    });

    test('identity axes stored independently (id ≠ label ≠ display name)', () {
      final tier = c1.tierById('tricky')!;
      expect(tier.difficultyLabel, 'Tricky');
      expect(tier.displayName, 'Tricky Glyphs');
      expect(tier.tierId, isNot(tier.difficultyLabel));
      expect(tier.tierId, isNot(tier.displayName));
      for (final level in tier.levels) {
        expect(level.chapterId, 'c1');
        expect(level.tierId, 'tricky');
      }
      // levelOrder is a 1-based sequence, not identity.
      expect([for (final l in tier.levels) l.levelOrder],
          [for (var i = 1; i <= tier.size; i++) i]);
    });

    test('lookups: levelsById, chapterOf, tierOf; unknown id -> null', () {
      expect(registry.levelsById.length, 100);
      expect(registry.chapterOf('rs_000')?.chapterId, 'c1');
      expect(registry.tierOf('rs_000')?.tierId, 'quick');
      expect(registry.tierOf('rs_099')?.tierId, 'deep');
      expect(registry.levelsById['rs_042']?.tierId, 'normal');
      expect(registry.levelsById['rs_999'], isNull);
      expect(registry.chapterOf('rs_999'), isNull);
      expect(registry.tierOf('rs_999'), isNull);
      expect(registry.chapterById('c2'), isNull);
    });
  });

  group('construction guards', () {
    test('duplicate level id across the campaign is rejected', () {
      expect(
          () => CampaignRegistry([
                ChapterDefinition(
                  chapterId: 'c_a',
                  order: 1,
                  coreBoardConfig: BoardConfig.sixBySix,
                  unlockPolicy: const ChapterUnlockPolicy.initiallyUnlocked(),
                  tiers: [
                    _tier('c_a', 't1', ['dup_1'],
                        const TierUnlockPolicy.initiallyUnlocked()),
                    _tier('c_a', 't2', ['dup_1'],
                        const TierUnlockPolicy.initiallyUnlocked()),
                  ],
                ),
              ]),
          throwsArgumentError);
    });

    test('unmapped Chapter 1 difficulty label is rejected', () {
      final pool = LevelPool([_puzzle('x_0', 'Tutorial')]);
      expect(() => CampaignRegistry.chapter1FromPool(pool),
          throwsArgumentError);
    });
  });

  group('policy evaluation over synthetic registries (target shape)', () {
    // Synthetic campaign: c_a (initially unlocked) has a core tier (4 levels),
    // a non-core bonus tier, and a disabled tier; c_b unlocks after 2 core
    // completions in c_a (2 = arbitrary synthetic value, NOT a shipped frozen
    // threshold — Chapter 1 gates stay live-computed in this batch).
    final campaign = CampaignRegistry([
      ChapterDefinition(
        chapterId: 'c_a',
        order: 1,
        coreBoardConfig: BoardConfig.sixBySix,
        unlockPolicy: const ChapterUnlockPolicy.initiallyUnlocked(),
        tiers: [
          _tier('c_a', 'core', ['a_1', 'a_2', 'a_3', 'a_4'],
              const TierUnlockPolicy.initiallyUnlocked()),
          _tier('c_a', 'bonus', ['x_1', 'x_2'],
              const TierUnlockPolicy.initiallyUnlocked(),
              countsTowardProgress: false, isOptionalExpert: true),
          _tier('c_a', 'sealed', ['s_1'],
              const TierUnlockPolicy.disabled()),
        ],
      ),
      ChapterDefinition(
        chapterId: 'c_b',
        order: 2,
        coreBoardConfig: BoardConfig.sixBySix,
        unlockPolicy: const ChapterUnlockPolicy.completedCoreCountInChapter(
            prerequisiteChapterId: 'c_a', coreLevelsRequired: 2),
        tiers: [
          _tier('c_b', 'main', ['b_1', 'b_2'],
              const TierUnlockPolicy.initiallyUnlocked()),
        ],
      ),
    ]);
    final reg = RegistryProgression(campaign);

    test('chapter gate counts only countsTowardProgress tiers', () {
      expect(reg.isChapterUnlocked('c_b', const {}), isFalse);
      expect(reg.isChapterUnlocked('c_b', {'a_1'}), isFalse);
      // Bonus-tier completions do not feed the core count.
      expect(reg.isChapterUnlocked('c_b', {'a_1', 'x_1', 'x_2'}), isFalse);
      expect(reg.isChapterUnlocked('c_b', {'a_1', 'a_2'}), isTrue);
      expect(reg.isChapterUnlocked('c_a', const {}), isTrue);
      expect(reg.isChapterUnlocked('missing', const {}), isFalse);
    });

    test('levels behind a locked chapter stay locked; unlock opens tier 1',
        () {
      expect(reg.isLevelUnlocked('b_1', {'a_1'}), isFalse);
      expect(reg.isTierUnlocked('c_b', 'main', {'a_1'}), isFalse);
      expect(reg.isLevelUnlocked('b_1', {'a_1', 'a_2'}), isTrue);
      expect(reg.isLevelUnlocked('b_2', {'a_1', 'a_2'}), isFalse,
          reason: 'sequential gate inside the tier still applies');
      expect(reg.computeUnlockedLevels({'a_1', 'a_2'}),
          containsAll(<String>{'b_1'}));
    });

    test('disabled tier never unlocks, but completed levels stay replayable',
        () {
      final everything = {
        'a_1', 'a_2', 'a_3', 'a_4', 'x_1', 'x_2', 'b_1', 'b_2'
      };
      expect(reg.isTierUnlocked('c_a', 'sealed', everything), isFalse);
      expect(reg.isLevelUnlocked('s_1', everything), isFalse);
      expect(reg.computeUnlockedLevels(everything), isNot(contains('s_1')));
      // Legacy replay quirk preserved: a completed id is always available.
      expect(reg.isLevelUnlocked('s_1', {...everything, 's_1'}), isTrue);
    });

    test('fail-closed guards: missing prerequisite -> never unlocks', () {
      final broken = CampaignRegistry([
        ChapterDefinition(
          chapterId: 'c_x',
          order: 1,
          coreBoardConfig: BoardConfig.sixBySix,
          unlockPolicy: const ChapterUnlockPolicy.initiallyUnlocked(),
          tiers: [
            _tier('c_x', 't1', ['m_1'],
                const TierUnlockPolicy.completedCountInTier(
                    prerequisiteTierId: 'ghost')),
          ],
        ),
      ]);
      final r = RegistryProgression(broken);
      expect(r.isTierUnlocked('c_x', 't1', {'m_1'}), isFalse);
      expect(r.nextLevelId(const {}), isNull);
    });
  });
}
