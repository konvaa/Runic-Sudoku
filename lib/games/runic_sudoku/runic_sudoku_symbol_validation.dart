import '../../core/theme/rune_set.dart';
import 'runic_sudoku_rules.dart';

/// Sudoku-specific symbol-set validation.
///
/// Kept OUT of [RunicSudokuRules] (as an extension here) so the rules stay free
/// of any Flutter import: `SymbolSet` → `VisualSymbol` → `Color` pulls in
/// `package:flutter/painting.dart`, and the Phase 2 solver/generator reuse
/// `RunicSudokuRules` as pure Dart. This rule still belongs to the game module,
/// not App Core / Theme. See PHASE2_NOTES.md "Specification ambiguities".
extension RunicSudokuSymbolValidation on RunicSudokuRules {
  /// Ensures a symbol set has enough symbols for this grid (at least [maxValue]
  /// for an n×n grid).
  void requireSymbolCount(SymbolSet set) {
    if (set.length < maxValue) {
      throw ArgumentError(
        'SymbolSet "${set.id}" has ${set.length} symbols but '
        '$maxValue are required for a ${dimensions.toToken()} grid.',
      );
    }
  }
}
