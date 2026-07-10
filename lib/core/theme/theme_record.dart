import 'package:flutter/material.dart';

/// Data describing one selectable app theme.
///
/// It references a symbol set by id only ([symbolSetId]); the Theme Manager
/// resolves the id to a `SymbolSet`. Theme data carries NO game rules.
class ThemeRecord {
  final String id;
  final String displayName;
  final Brightness brightness;
  final Color seedColor;

  /// Board surface color.
  final Color boardBackground;

  /// Thin per-cell line color.
  final Color cellBorder;

  /// Thick box-boundary line color.
  final Color boxBorder;

  /// Id of the symbol set this theme prefers (resolved by ThemeManager).
  ///
  /// NOTE(chapter-system): both built-in themes currently point at
  /// 'elder_futhark_6', a 6-symbol set sized for the 6×6 board. A larger board
  /// needs a set with >= runeCount symbols (enforced at screen load by
  /// `RunicSudokuSymbolValidation.requireSymbolCount`); per-board symbol-set
  /// selection is future work (see dev_notes/fable_step0_inventory_result.md).
  final String symbolSetId;

  const ThemeRecord({
    required this.id,
    required this.displayName,
    required this.brightness,
    required this.seedColor,
    required this.boardBackground,
    required this.cellBorder,
    required this.boxBorder,
    required this.symbolSetId,
  });
}

/// Built-in theme catalogue for Phase 1.
class AppThemes {
  static const runesLight = ThemeRecord(
    id: 'runes_light',
    displayName: 'Runes (Light)',
    brightness: Brightness.light,
    seedColor: Color(0xFF6D4C41),
    boardBackground: Color(0xFFFDF6EC),
    cellBorder: Color(0xFFD7CCC8),
    boxBorder: Color(0xFF4E342E),
    symbolSetId: 'elder_futhark_6',
  );

  static const runesDark = ThemeRecord(
    id: 'runes_dark',
    displayName: 'Runes (Dark)',
    brightness: Brightness.dark,
    seedColor: Color(0xFF8D6E63),
    boardBackground: Color(0xFF2B2622),
    cellBorder: Color(0xFF4E443D),
    boxBorder: Color(0xFFD7CCC8),
    symbolSetId: 'elder_futhark_6',
  );

  static const all = <ThemeRecord>[runesLight, runesDark];
}
