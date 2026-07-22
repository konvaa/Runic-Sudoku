// 9×9 feasibility spike (see docs/9x9_generation_feasibility_prompt.md):
// verifies the Step 0 "requireSymbolCount throws for maxValue > 6" flag.
//
// Finding: the guard itself is already count-generic (`set.length < maxValue`,
// board-agnostic error text since Batch 1) — it threw for maxValue > 6 only
// because no ≥9-symbol set existed before Batch 2 added `elderFutharkNineSet`.
// These tests lock the resolved behavior: a 9×9 rules instance accepts the
// 9-symbol set and (still, correctly) rejects the 6-symbol sets. No production
// code change was needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/theme/rune_set.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_rules.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_symbol_validation.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const nineRules = RunicSudokuRules(
    dimensions: GridDimensions(rows: 9, cols: 9),
    boxShape: BoxShape(rows: 3, cols: 3),
    runeCount: 9,
  );

  test('9x9 rules derive runeCount/maxValue 9', () {
    expect(nineRules.runeCount, 9);
    expect(nineRules.maxValue, 9);
  });

  test('requireSymbolCount accepts elderFutharkNineSet on a 9x9 board', () {
    expect(
      () => nineRules.requireSymbolCount(elderFutharkNineSet),
      returnsNormally,
    );
  });

  test('requireSymbolCount still rejects the 6-symbol sets on a 9x9 board', () {
    expect(
      () => nineRules.requireSymbolCount(defaultRuneSet),
      throwsArgumentError,
    );
    expect(
      () => nineRules.requireSymbolCount(numericSet),
      throwsArgumentError,
    );
  });

  test('6x6 rules still accept both 6-symbol sets and the 9-symbol superset',
      () {
    const sixRules = RunicSudokuRules.sixBySix;
    expect(() => sixRules.requireSymbolCount(defaultRuneSet), returnsNormally);
    expect(() => sixRules.requireSymbolCount(numericSet), returnsNormally);
    // A superset is fine: the guard requires *at least* maxValue symbols.
    expect(
      () => sixRules.requireSymbolCount(elderFutharkNineSet),
      returnsNormally,
    );
  });
}
