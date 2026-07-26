// Differential golden test for Batch 2 (static contract):
// legacy `Progression` vs the new registry-driven `RegistryProgression`, run
// side-by-side over a wide corpus of completed_level_ids sets. ANY output
// difference fails the batch (no intended differences exist in this batch).
//
// Independence: `RegistryProgression` re-implements the semantics over
// `CampaignRegistry` structures and never delegates to legacy `Progression`
// (registry_progression.dart does not even import progression.dart). The two
// sides share only immutable domain data (`ManualPuzzle` payloads, the pool
// asset) and the standard library.
//
// Vocabulary adapter (TEST ONLY, per the batch prompt): legacy difficulty-band
// chapters map to c1 tiers as chapter_1→c1/quick, chapter_2→c1/normal,
// chapter_3→c1/tricky, chapter_4→c1/deep. The adapter has no life outside this
// test; the new identifiers are never persisted.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/chapter_registry.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/registry_progression.dart';

/// Fixed corpus seed — the randomized part of the corpus is fully
/// deterministic and reproduces identically on every run.
const int corpusSeed = 0xC0FFEE; // 12648430

/// Deterministic Lehmer/MINSTD LCG. Implemented locally so corpus
/// reproducibility does not depend on Dart SDK `Random` internals.
class _Lcg {
  int _state;
  _Lcg(int seed) : _state = seed % 2147483647 {
    if (_state <= 0) _state += 2147483646;
  }

  /// Uniform int in [0, bound).
  int next(int bound) {
    _state = (_state * 48271) % 2147483647;
    return _state % bound;
  }
}

/// Test-only vocabulary adapter: legacy band-chapter id -> new tier id.
const Map<String, String> bandToTier = {
  'chapter_1': 'quick',
  'chapter_2': 'normal',
  'chapter_3': 'tricky',
  'chapter_4': 'deep',
};

void main() {
  final pool = LevelPool.fromJsonString(
      File(LevelPool.assetPath).readAsStringSync());
  final legacy = Progression.fromPool(pool);
  final registry = CampaignRegistry.chapter1FromPool(pool);
  final reg = RegistryProgression(registry);

  final allIds = [for (final l in pool.levels) l.levelId];
  final quick = [for (final p in pool.byLabel('Quick')) p.levelId];
  final normal = [for (final p in pool.byLabel('Normal')) p.levelId];
  final tricky = [for (final p in pool.byLabel('Tricky')) p.levelId];
  final deep = [for (final p in pool.byLabel('Deep')) p.levelId];
  final tiersById = {
    for (final t in registry.chapters.single.tiers) t.tierId: t,
  };

  /// Compares every output pair for one completed-set; returns the number of
  /// individual comparisons made.
  int compareAll(String desc, Set<String> completed) {
    var checks = 0;
    void eq(Object? a, Object? b, String what) {
      expect(b, equals(a), reason: '[$desc] $what diverged');
      checks++;
    }

    // Derived sets / aggregates.
    eq(legacy.computeUnlockedLevels(completed),
        reg.computeUnlockedLevels(completed), 'unlocked level ids');
    eq(
        {
          for (final id in legacy.computeUnlockedChapters(completed))
            'c1/${bandToTier[id]}',
        },
        reg.computeUnlockedTiers(completed),
        'unlocked tier/band state');
    eq(
        {
          for (final e in legacy.chapterProgress(completed).entries)
            'c1/${bandToTier[e.key]}': e.value,
        },
        reg.tierProgress(completed),
        'progress values');
    eq(legacy.nextLevelId(completed), reg.nextLevelId(completed),
        'next level');
    eq(legacy.isFreePlayUnlocked(completed),
        reg.isFreePlayUnlocked(completed), 'free-play unlock');

    // Per-band unlock state, progress count and live threshold.
    for (final chapter in legacy.chapters) {
      final tier = tiersById[bandToTier[chapter.id]]!;
      eq(legacy.isChapterUnlocked(chapter.id, completed),
          reg.isTierUnlocked('c1', tier.tierId, completed),
          'unlock state of ${chapter.id}/${tier.tierId}');
      eq(legacy.completedInChapter(chapter, completed),
          reg.completedInTier(tier, completed),
          'completed count in ${chapter.id}/${tier.tierId}');
      eq(legacy.thresholdFor(chapter), reg.requiredFromPrerequisite(tier),
          'live threshold of ${chapter.id}/${tier.tierId}');
    }

    // Per-level availability for every pool level (covers replay-ability of
    // completed levels too).
    for (final id in allIds) {
      eq(legacy.isLevelUnlocked(id, completed),
          reg.isLevelUnlocked(id, completed), 'availability of $id');
    }

    // Ids in the completed set that the pool does NOT know (unknown-id
    // robustness): both sides must agree here as well.
    for (final id in completed) {
      if (!legacy.levelsById.containsKey(id)) {
        eq(legacy.isLevelUnlocked(id, completed),
            reg.isLevelUnlocked(id, completed),
            'availability of unknown id $id');
      }
    }
    return checks;
  }

  group('structural parity (registry mirrors the legacy model exactly)', () {
    test('bands and tiers: same levels, same order, same names, same labels',
        () {
      expect(registry.chapters.single.chapterId, 'c1');
      expect(legacy.chapters.length,
          registry.chapters.single.tiers.length);
      for (final chapter in legacy.chapters) {
        final tier = tiersById[bandToTier[chapter.id]]!;
        expect(tier.levelIds, equals(chapter.levelIds),
            reason: '${chapter.id}: level ids/order must match');
        expect(tier.displayName, chapter.displayName,
            reason: '${chapter.id}: display name must match current UI');
        expect(tier.difficultyLabel, chapter.difficultyLabel);
      }
      expect(registry.levelsById.length, 100);
      expect(registry.levelsById.keys.toSet(),
          legacy.levelsById.keys.toSet());
    });

    test('tier gates are explicit-id, live-fraction — nothing frozen', () {
      expect(tiersById['quick']!.unlockPolicy.type,
          TierUnlockPolicyType.initiallyUnlocked);
      expect(tiersById['normal']!.unlockPolicy.prerequisiteTierId, 'quick');
      expect(tiersById['tricky']!.unlockPolicy.prerequisiteTierId, 'normal');
      expect(tiersById['deep']!.unlockPolicy.prerequisiteTierId, 'tricky');
      // Live thresholds equal legacy's live formula at current sizes
      // (10/15/15 today) — computed, not stored.
      expect(reg.requiredFromPrerequisite(tiersById['quick']!), 10);
      expect(reg.requiredFromPrerequisite(tiersById['normal']!), 15);
      expect(reg.requiredFromPrerequisite(tiersById['tricky']!), 15);
    });
  });

  group('differential corpus (legacy vs registry, zero differences allowed)',
      () {
    test('full corpus comparison', () {
      var sets = 0;
      var checks = 0;
      void run(String desc, Set<String> completed) {
        checks += compareAll(desc, completed);
        sets++;
      }

      // -- Empty profile.
      run('empty', const <String>{});

      // -- Boundary sets on both sides of every existing live threshold
      //    (quick: 10 of 20; normal/tricky: 15 of 30), prefix and scattered.
      run('quick 9/10 (prefix)', {...quick.take(9)});
      run('quick 10/10 (prefix)', {...quick.take(10)});
      run('quick 9 scattered',
          {for (var i = 0; i < 18; i += 2) quick[i]});
      run('quick10 + normal 14/15', {...quick.take(10), ...normal.take(14)});
      run('quick10 + normal 15/15', {...quick.take(10), ...normal.take(15)});
      run('quick10 + normal15 + tricky 14/15',
          {...quick.take(10), ...normal.take(15), ...tricky.take(14)});
      run('quick10 + normal15 + tricky 15/15',
          {...quick.take(10), ...normal.take(15), ...tricky.take(15)});
      run('normal 14 alone (progress in a locked band)',
          {...normal.take(14)});
      run('tricky 15 alone (threshold met, band still locked)',
          {...tricky.take(15)});

      // -- Every prefix of the pool, k = 0..100.
      for (var k = 0; k <= 100; k++) {
        run('prefix k=$k', {...allIds.take(k)});
      }

      // -- Each tier fully completed in isolation.
      run('quick complete only', {...quick});
      run('normal complete only', {...normal});
      run('tricky complete only', {...tricky});
      run('deep complete only', {...deep});

      // -- The fully completed pool.
      run('all 100 complete', {...allIds});

      // -- Randomized out-of-order sets, deterministic (seed reported below).
      final rng = _Lcg(corpusSeed);
      Set<String> sampleFrom(List<String> ids, int n) {
        final copy = [...ids];
        for (var i = copy.length - 1; i > 0; i--) {
          final j = rng.next(i + 1);
          final t = copy[i];
          copy[i] = copy[j];
          copy[j] = t;
        }
        return {...copy.take(n)};
      }

      final tierLists = [quick, normal, tricky, deep];
      for (var i = 0; i < 130; i++) {
        run('random sparse #$i', sampleFrom(allIds, 1 + rng.next(15)));
      }
      for (var i = 0; i < 130; i++) {
        run('random medium #$i', sampleFrom(allIds, 30 + rng.next(31)));
      }
      for (var i = 0; i < 130; i++) {
        run('random dense #$i', sampleFrom(allIds, 80 + rng.next(20)));
      }
      for (var i = 0; i < 65; i++) {
        final tier = tierLists[rng.next(tierLists.length)];
        run('random tier-local #$i',
            sampleFrom(tier, 1 + rng.next(tier.length)));
      }
      for (var i = 0; i < 65; i++) {
        final a = rng.next(tierLists.length);
        var b = rng.next(tierLists.length);
        if (b == a) b = (b + 1) % tierLists.length;
        final set = <String>{
          ...sampleFrom(tierLists[a], 1 + rng.next(tierLists[a].length)),
          ...sampleFrom(tierLists[b], 1 + rng.next(tierLists[b].length)),
        };
        if (rng.next(2) == 1) {
          set.addAll(sampleFrom(
              tierLists[rng.next(tierLists.length)], 1 + rng.next(5)));
        }
        run('random cross-tier #$i', set);
      }

      // -- Unknown-id robustness: non-existent historical ids mixed into
      //    otherwise-valid sets (both sides must behave identically).
      run('unknown id alone', {'rs_999'});
      run('unknown id + quick 10',
          {'rs_999', ...quick.take(10)});
      run('full quick + foreign-namespace id',
          {...quick, 'c9_bogus_001'});
      run('prefix 50 + two unknown ids',
          {...allIds.take(50), 'rs_999', 'not_a_level'});

      // Corpus accounting (cited in the batch report).
      // 1 empty + 9 boundary + 101 prefixes + 4 tier-isolation + 1 full
      // + 520 randomized + 4 unknown-id = 640 compared profile states.
      expect(sets, 640, reason: 'corpus size must be exactly as reported');
      expect(checks, greaterThan(60000));
      // ignore: avoid_print
      print('differential corpus: seed=0x${corpusSeed.toRadixString(16)}, '
          '520 randomized sets, $sets compared profile states, '
          '$checks individual output comparisons, zero differences');
    });
  });
}
