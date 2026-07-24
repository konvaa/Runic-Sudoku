// Golden + compatibility tests for the Chapter 1 schema freeze (Batch 1).
//
// The shipped Chapter 1 pool asset was converted from the legacy positional
// schema (version 0, no level_id) to the explicit-id schema (version 1) by
// tool/backfill_chapter1_level_ids.dart. These tests prove the conversion
// changed NOTHING except the envelope + explicit ids:
//
//   1. every explicit id equals the historical positional id (rs_000…rs_099);
//   2. ids are exactly the set rs_000…rs_099, non-empty, unique;
//   3. puzzle content is deeply equivalent to the frozen legacy baseline
//      (test/fixtures/chapter1_pool_legacy_50ccb80.json — a byte-identical
//      copy of the asset's Git blob at commit 50ccb80);
//   4. difficulty bands stay exactly Quick 20 / Normal 30 / Tricky 30 / Deep 20;
//   5. campaign save keys stay exactly runic_sudoku/rs_NNN;
//   6. existing completed_level_ids resolve to the same levels and the same
//      progression state before and after the schema change;
//   7. Daily Puzzle selection is identical before/after across 1100 dates;
//   8. schema validation: legacy pools still load; bad explicit ids are
//      rejected; identity survives reordering in the new schema.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_snapshot.dart';

/// Frozen legacy baseline: byte-identical copy of
/// assets/levels/runic_sudoku_levels.json at Git commit 50ccb80 (the reviewed
/// design-batch head), i.e. the exact pool shipped before the schema freeze.
const String legacyFixturePath =
    'test/fixtures/chapter1_pool_legacy_50ccb80.json';

void main() {
  final legacyText = File(legacyFixturePath).readAsStringSync();
  final newText = File(LevelPool.assetPath).readAsStringSync();

  final legacyDoc = jsonDecode(legacyText) as Map<String, dynamic>;
  final newDoc = jsonDecode(newText) as Map<String, dynamic>;

  // Parsed through the SAME production parser the app uses: the fixture takes
  // the legacy (schema version 0, positional) path, the shipped asset takes
  // the explicit-id (schema version 1) path.
  final legacyPool = LevelPool.fromJsonString(legacyText);
  final newPool = LevelPool.fromJsonString(newText);

  group('shipped asset envelope', () {
    test('fixture is the legacy schema; shipped asset is explicit-id v1', () {
      expect(legacyDoc.containsKey('schema_version'), isFalse,
          reason: 'baseline fixture must be the pre-freeze legacy schema');
      expect(newDoc['schema_version'], 1);
      expect(newDoc['chapter_id'], 'c1');
      expect(newDoc['pool_version'], 1);
    });

    test('pre-existing envelope fields are preserved unchanged', () {
      for (final key in ['schema', 'note', 'grid_size', 'box_shape', 'counts']) {
        expect(newDoc[key], equals(legacyDoc[key]),
            reason: 'envelope field "$key" must survive the conversion');
      }
    });
  });

  group('golden identity mapping (G3)', () {
    test('both pools load exactly 100 levels', () {
      expect(legacyPool.length, 100);
      expect(newPool.length, 100);
    });

    test('explicit id == historical positional id for every index 0–99', () {
      for (var i = 0; i < 100; i++) {
        final positional = LevelPool.levelIdForIndex(i);
        expect(newPool.levels[i].levelId, positional,
            reason: 'index $i must keep its positional identity');
        expect(legacyPool.levels[i].levelId, positional);
      }
    });

    test('ids are exactly the set rs_000…rs_099, non-empty, unique', () {
      final ids = [for (final l in newPool.levels) l.levelId];
      expect(ids.every((id) => id.isNotEmpty), isTrue);
      expect(ids.toSet().length, 100, reason: 'ids must be unique');
      expect(ids.toSet(),
          {for (var i = 0; i < 100; i++) LevelPool.levelIdForIndex(i)});
    });
  });

  group('puzzle-content equivalence vs frozen baseline', () {
    test('raw records match the Git baseline, ignoring only envelope + id', () {
      final legacyEntries =
          (legacyDoc['levels'] as List).cast<Map<String, dynamic>>();
      final newEntries =
          (newDoc['levels'] as List).cast<Map<String, dynamic>>();
      expect(newEntries.length, legacyEntries.length);
      for (var i = 0; i < legacyEntries.length; i++) {
        expect(legacyEntries[i].containsKey('level_id'), isFalse);
        final stripped = Map<String, dynamic>.of(newEntries[i])
          ..remove('level_id');
        expect(stripped, equals(legacyEntries[i]),
            reason: 'entry $i content must be byte-for-byte equivalent');
      }
    });

    test('parsed puzzles are field-for-field identical per index', () {
      for (var i = 0; i < 100; i++) {
        final a = legacyPool.levels[i];
        final b = newPool.levels[i];
        expect(b.levelId, a.levelId);
        expect(b.seed, a.seed);
        expect(b.gridSize, a.gridSize);
        expect(b.boxShape, a.boxShape);
        expect(b.solutionGrid, equals(a.solutionGrid));
        expect(b.givenCells, equals(a.givenCells));
        expect(b.difficultyLabel, a.difficultyLabel);
        expect(b.estimatedSolveTime, a.estimatedSolveTime);
      }
    });
  });

  group('difficulty-band preservation', () {
    test('exactly Quick 20 / Normal 30 / Tricky 30 / Deep 20, in order', () {
      const expected = {'Quick': 20, 'Normal': 30, 'Tricky': 30, 'Deep': 20};
      for (final pool in [legacyPool, newPool]) {
        expect(pool.presentLabels, ['Quick', 'Normal', 'Tricky', 'Deep']);
        expected.forEach((label, count) {
          expect(pool.byLabel(label).length, count,
              reason: '$label band must keep exactly $count levels');
        });
      }
      // Band membership per id is unchanged.
      for (var i = 0; i < 100; i++) {
        expect(newPool.levels[i].difficultyLabel,
            legacyPool.levels[i].difficultyLabel);
      }
    });
  });

  group('save-key preservation', () {
    test('campaign save key stays runic_sudoku/rs_NNN for every level', () {
      for (var i = 0; i < 100; i++) {
        final id = newPool.levels[i].levelId;
        expect(saveKeyFor(PuzzleMode.campaign, id),
            'runic_sudoku/${LevelPool.levelIdForIndex(i)}');
      }
    });
  });

  group('completed_level_ids compatibility', () {
    // Representative existing progress: band boundaries + interior ids.
    const completed = {
      'rs_000', 'rs_010', 'rs_019', // Quick (0–19)
      'rs_020', 'rs_042', 'rs_049', // Normal (20–49)
      'rs_050', 'rs_079', // Tricky (50–79)
      'rs_080', 'rs_099', // Deep (80–99)
    };

    test('every persisted id resolves to the same level in both pools', () {
      for (final id in completed) {
        final a = legacyPool.byId(id);
        final b = newPool.byId(id);
        expect(a, isNotNull, reason: '$id must resolve in the legacy pool');
        expect(b, isNotNull, reason: '$id must resolve in the new pool');
        expect(b!.givenCells, equals(a!.givenCells),
            reason: '$id must be the same puzzle before and after');
        expect(b.solutionGrid, equals(a.solutionGrid));
        expect(b.difficultyLabel, a.difficultyLabel);
      }
    });

    test('derived progression state is identical before and after', () {
      final a = Progression.fromPool(legacyPool);
      final b = Progression.fromPool(newPool);
      expect(b.chapterProgress(completed), equals(a.chapterProgress(completed)));
      expect(b.computeUnlockedLevels(completed),
          equals(a.computeUnlockedLevels(completed)));
      expect(b.computeUnlockedChapters(completed),
          equals(a.computeUnlockedChapters(completed)));
      expect(b.nextLevelId(completed), a.nextLevelId(completed));
      expect(b.isFreePlayUnlocked(completed), a.isFreePlayUnlocked(completed));
    });
  });

  group('Daily Puzzle stability', () {
    test('selected level id identical before/after across 1100 dates', () {
      for (var d = 0; d < 1100; d++) {
        // Day-overflow construction is DST-safe (no Duration arithmetic).
        final date = DateTime(2026, 1, 1 + d);
        final a = legacyPool.dailyFor(date);
        final b = newPool.dailyFor(date);
        expect(b.levelId, a.levelId,
            reason: 'daily selection for $date must not change');
        expect(b.givenCells, equals(a.givenCells),
            reason: 'daily puzzle content for $date must not change');
      }
    });
  });

  group('schema validation', () {
    Map<String, dynamic> entry({String? id, required int seed}) => {
          if (id != null) 'level_id': id,
          'grid_size': '1x1',
          'box_shape': '1x1',
          'solution_grid': [
            [1]
          ],
          'given_cells': [
            [0]
          ],
          'difficulty_label': 'Quick',
          'estimated_solve_time': 1000,
          'seed': seed,
        };

    String pool(List<Map<String, dynamic>> entries, {int? version}) =>
        jsonEncode({
          if (version != null) 'schema_version': version,
          'levels': entries,
        });

    test('legacy pool (no schema_version) still loads positionally', () {
      final p = LevelPool.fromJsonString(
          pool([entry(seed: 1), entry(seed: 2)]));
      expect(p.length, 2);
      expect(p.levels[0].levelId, 'rs_000');
      expect(p.levels[1].levelId, 'rs_001');
      // Empty legacy pool keeps loading too (existing widget_test behaviour).
      expect(LevelPool.fromJsonString('{"levels":[]}').length, 0);
    });

    test('explicit-id pool loads and ids are opaque (no rs_NNN shape needed)',
        () {
      final p = LevelPool.fromJsonString(pool(
          [entry(id: 'alpha', seed: 1), entry(id: 'beta', seed: 2)],
          version: 1));
      expect(p.length, 2);
      expect(p.byId('alpha')!.seed, 1);
      expect(p.byId('beta')!.seed, 2);
    });

    test('missing level_id in the new schema is rejected', () {
      expect(
          () => LevelPool.fromJsonString(
              pool([entry(id: 'alpha', seed: 1), entry(seed: 2)], version: 1)),
          throwsFormatException);
    });

    test('empty level_id in the new schema is rejected', () {
      expect(
          () => LevelPool.fromJsonString(
              pool([entry(id: '', seed: 1)], version: 1)),
          throwsFormatException);
    });

    test('duplicate level_id in the new schema is rejected', () {
      expect(
          () => LevelPool.fromJsonString(pool(
              [entry(id: 'alpha', seed: 1), entry(id: 'alpha', seed: 2)],
              version: 1)),
          throwsFormatException);
    });

    test('unsupported schema_version is rejected', () {
      expect(
          () => LevelPool.fromJsonString(
              pool([entry(id: 'alpha', seed: 1)], version: 99)),
          throwsFormatException);
    });

    test('identity survives reordering (synthetic fixture, new schema)', () {
      final ordered = LevelPool.fromJsonString(pool(
          [entry(id: 'alpha', seed: 1), entry(id: 'beta', seed: 2)],
          version: 1));
      final reordered = LevelPool.fromJsonString(pool(
          [entry(id: 'beta', seed: 2), entry(id: 'alpha', seed: 1)],
          version: 1));
      // Same identity → same puzzle, regardless of array position.
      expect(reordered.byId('alpha')!.seed, ordered.byId('alpha')!.seed);
      expect(reordered.byId('beta')!.seed, ordered.byId('beta')!.seed);
      // And position no longer dictates identity.
      expect(reordered.levels[0].levelId, 'beta');
      expect(ordered.levels[0].levelId, 'alpha');
    });
  });
}
