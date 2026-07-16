// Batch 2 (chapter-system refactor) coverage — NEW tests only, existing tests
// are untouched:
//  1. BoardConfig value semantics + JSON round-trip (isolate payload format).
//  2. GOLDEN IDENTITY: the required-BoardConfig PuzzleGenerator reproduces the
//     SHIPPED Chapter 1 pool entries bit-identically from their stored seeds,
//     proving the constructor refactor did not alter the generation path.
//  3. The new 9-symbol rune set is well-formed and NOT reachable from any
//     theme / ThemeManager default.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/theme/rune_set.dart';
import 'package:runic_sudoku/core/theme/theme_manager.dart';
import 'package:runic_sudoku/core/theme/theme_record.dart';
import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';

void main() {
  group('BoardConfig', () {
    test('sixBySix is valid and matches Chapter 1 dimensions', () {
      const b = BoardConfig.sixBySix;
      expect(b.isValid, isTrue);
      expect(b.dimensions.rows, 6);
      expect(b.dimensions.cols, 6);
      expect(b.boxShape.rows, 2);
      expect(b.boxShape.cols, 3);
      expect(b.runeCount, 6);
    });

    test('round-trips through JSON (isolate payload wire form)', () {
      const b = BoardConfig.sixBySix;
      final json = b.toJson();
      expect(json['grid_size'], '6x6');
      expect(json['box_shape'], '2x3');
      expect(json['rune_count'], 6);
      final restored = BoardConfig.fromJson(json);
      expect(restored, b);
      expect(restored.hashCode, b.hashCode);
    });
  });

  group('PuzzleGenerator(required BoardConfig) — Chapter 1 output identity', () {
    test('regenerating shipped pool entries from stored seeds is identical',
        () {
      // The shipped asset was generated BEFORE this refactor, so reproducing
      // its entries from their stored seeds is a true cross-refactor golden
      // check: same full grid, same carve, same difficulty label.
      final file = File(LevelPool.assetPath);
      expect(file.existsSync(), isTrue,
          reason: 'shipped Chapter 1 pool asset must be present');
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final levels = (doc['levels'] as List).cast<Map<String, dynamic>>();
      expect(levels, isNotEmpty);

      // First entry of each label present in the pool. Deep is fine here: the
      // stored seed is the successful attempt seed, so generation succeeds on
      // attempt 0 (one carve pass), which is fast.
      final byLabel = <String, Map<String, dynamic>>{};
      for (final e in levels) {
        byLabel.putIfAbsent(e['difficulty_label'] as String, () => e);
      }

      final generator = PuzzleGenerator(board: BoardConfig.sixBySix);
      byLabel.forEach((token, entry) {
        final seed = (entry['seed'] as num?)?.toInt();
        expect(seed, isNotNull,
            reason: 'pool entries store their generation seed');
        final r = generator.generate(
          target: DifficultyLabel.fromToken(token),
          seed: seed!,
          maxAttempts: 1,
        );
        expect(r.attempts, 1,
            reason: '$token: stored seed must succeed on the first attempt');
        expect(r.level.solutionGrid, entry['solution_grid'],
            reason: '$token: solution grid must match the shipped asset');
        expect(r.level.givenCells, entry['given_cells'],
            reason: '$token: given cells must match the shipped asset');
        expect(r.level.difficultyLabel, token);
        expect(r.level.gridSize.toToken(), '6x6');
        expect(r.level.boxShape.toToken(), '2x3');
      });
    });
  });

  group('elderFutharkNineSet (additive only)', () {
    test('has 9 symbols in stable order; first six identical to the 6-set',
        () {
      expect(elderFutharkNineSet.id, 'elder_futhark_9');
      expect(elderFutharkNineSet.length, 9);
      for (var v = 1; v <= 6; v++) {
        expect(elderFutharkNineSet.forValue(v).glyph,
            defaultRuneSet.forValue(v).glyph,
            reason: 'value $v must render the same glyph as elder_futhark_6');
        expect(elderFutharkNineSet.forValue(v).id,
            defaultRuneSet.forValue(v).id);
        expect(elderFutharkNineSet.forValue(v).displayName,
            defaultRuneSet.forValue(v).displayName);
      }
      // Canonical Elder Futhark continuation: Gebo, Wunjo, Hagalaz.
      final glyphs = [for (final s in elderFutharkNineSet.symbols) s.glyph];
      expect(glyphs.sublist(6), ['ᚷ', 'ᚹ', 'ᚺ']);
      expect(glyphs.toSet().length, 9, reason: 'glyphs must be unique');
      expect({for (final s in elderFutharkNineSet.symbols) s.id}.length, 9,
          reason: 'symbol ids must be unique');
    });

    test('is NOT reachable from any theme or ThemeManager default', () {
      final manager = ThemeManager();
      expect(manager.symbolSetById('elder_futhark_9'), isNull,
          reason: 'must not be registered in the default symbol-set map');
      for (final t in AppThemes.all) {
        expect(t.symbolSetId, isNot('elder_futhark_9'),
            reason: 'no built-in theme may reference the 9-symbol set');
      }
    });
  });
}
