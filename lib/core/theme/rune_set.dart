import 'package:flutter/painting.dart' show Color;

/// One renderable symbol. Explicit by design (see PHASE1_NOTES.md): we do NOT
/// use Flutter `IconData` or bare strings/asset paths, because symbol sets must
/// support custom rune artwork, a text fallback, optional styling, and an
/// accessibility label together.
///
/// Rendering precedence: if [assetPath] is set, draw the asset; otherwise draw
/// [glyph] as text. [glyph] therefore doubles as the fallback for asset sets.
class VisualSymbol {
  /// Stable per-symbol id within its set (e.g. "rune_1").
  final String id;

  /// Text glyph used for rendering (or as fallback when [assetPath] is set).
  final String glyph;

  /// Optional image asset path; null means "render [glyph] as text".
  final String? assetPath;

  /// Optional tint/style color override; null means use the theme default.
  final Color? color;

  /// Human-facing name (localizable) — e.g. "Fehu".
  final String displayName;

  /// Screen-reader label — e.g. "Rune one, Fehu".
  final String accessibilityLabel;

  const VisualSymbol({
    required this.id,
    required this.glyph,
    this.assetPath,
    this.color,
    required this.displayName,
    required this.accessibilityLabel,
  });
}

/// An ordered collection of [VisualSymbol]s, identified by [id].
///
/// App Core / Theme treat this generically and make NO assumption about the
/// count of symbols. A game module validates the count it needs (Runic Sudoku
/// requires exactly 6 for 6x6 — see `RunicSudokuRules.requireSymbolCount`).
class SymbolSet {
  final String id;
  final List<VisualSymbol> symbols;

  const SymbolSet({required this.id, required this.symbols});

  int get length => symbols.length;

  VisualSymbol operator [](int index) => symbols[index];

  /// 1-based value -> symbol (sudoku uses values 1..n). Throws if out of range.
  VisualSymbol forValue(int value) => symbols[value - 1];
}

/// Default Elder-Futhark rune set with six symbols, sufficient for 6x6 play.
const SymbolSet defaultRuneSet = SymbolSet(
  id: 'elder_futhark_6',
  symbols: [
    VisualSymbol(
        id: 'rune_1',
        glyph: 'ᚠ',
        displayName: 'Fehu',
        accessibilityLabel: 'Rune one, Fehu'),
    VisualSymbol(
        id: 'rune_2',
        glyph: 'ᚢ',
        displayName: 'Uruz',
        accessibilityLabel: 'Rune two, Uruz'),
    VisualSymbol(
        id: 'rune_3',
        glyph: 'ᚦ',
        displayName: 'Thurisaz',
        accessibilityLabel: 'Rune three, Thurisaz'),
    VisualSymbol(
        id: 'rune_4',
        glyph: 'ᚨ',
        displayName: 'Ansuz',
        accessibilityLabel: 'Rune four, Ansuz'),
    VisualSymbol(
        id: 'rune_5',
        glyph: 'ᚱ',
        displayName: 'Raido',
        accessibilityLabel: 'Rune five, Raido'),
    VisualSymbol(
        id: 'rune_6',
        glyph: 'ᚲ',
        displayName: 'Kenaz',
        accessibilityLabel: 'Rune six, Kenaz'),
  ],
);

/// Elder-Futhark rune set with NINE symbols, sufficient for future 9×9 play.
///
/// Purely additive (chapter-system refactor, Batch 2): it is NOT referenced by
/// any theme (`AppThemes` still points at 'elder_futhark_6') or screen, and is
/// not registered in ThemeManager's defaults — it exists so a 9-rune board has
/// a symbol set to validate against once a 9×9 chapter ships. Nothing makes it
/// reachable from UI today.
///
/// SYMBOL ORDER IS STABLE AND LOAD-BEARING (index = 1-based rune value, the
/// same convention as [defaultRuneSet]): the first six symbols are IDENTICAL to
/// 'elder_futhark_6' (Fehu…Kenaz), followed by the next three runes of the
/// canonical Elder Futhark sequence (Gebo, Wunjo, Hagalaz). Do not reorder —
/// once a 9×9 chapter ships, reordering would silently remap every player's
/// placed values to different glyphs.
const SymbolSet elderFutharkNineSet = SymbolSet(
  id: 'elder_futhark_9',
  symbols: [
    VisualSymbol(
        id: 'rune_1',
        glyph: 'ᚠ',
        displayName: 'Fehu',
        accessibilityLabel: 'Rune one, Fehu'),
    VisualSymbol(
        id: 'rune_2',
        glyph: 'ᚢ',
        displayName: 'Uruz',
        accessibilityLabel: 'Rune two, Uruz'),
    VisualSymbol(
        id: 'rune_3',
        glyph: 'ᚦ',
        displayName: 'Thurisaz',
        accessibilityLabel: 'Rune three, Thurisaz'),
    VisualSymbol(
        id: 'rune_4',
        glyph: 'ᚨ',
        displayName: 'Ansuz',
        accessibilityLabel: 'Rune four, Ansuz'),
    VisualSymbol(
        id: 'rune_5',
        glyph: 'ᚱ',
        displayName: 'Raido',
        accessibilityLabel: 'Rune five, Raido'),
    VisualSymbol(
        id: 'rune_6',
        glyph: 'ᚲ',
        displayName: 'Kenaz',
        accessibilityLabel: 'Rune six, Kenaz'),
    VisualSymbol(
        id: 'rune_7',
        glyph: 'ᚷ',
        displayName: 'Gebo',
        accessibilityLabel: 'Rune seven, Gebo'),
    VisualSymbol(
        id: 'rune_8',
        glyph: 'ᚹ',
        displayName: 'Wunjo',
        accessibilityLabel: 'Rune eight, Wunjo'),
    VisualSymbol(
        id: 'rune_9',
        glyph: 'ᚺ',
        displayName: 'Hagalaz',
        accessibilityLabel: 'Rune nine, Hagalaz'),
  ],
);

/// A plain numeric symbol set (1..6) — handy for the planned 4x4 tutorial,
/// debugging, and players who prefer digits.
const SymbolSet numericSet = SymbolSet(
  id: 'numeric_6',
  symbols: [
    VisualSymbol(id: 'num_1', glyph: '1', displayName: 'One', accessibilityLabel: 'One'),
    VisualSymbol(id: 'num_2', glyph: '2', displayName: 'Two', accessibilityLabel: 'Two'),
    VisualSymbol(id: 'num_3', glyph: '3', displayName: 'Three', accessibilityLabel: 'Three'),
    VisualSymbol(id: 'num_4', glyph: '4', displayName: 'Four', accessibilityLabel: 'Four'),
    VisualSymbol(id: 'num_5', glyph: '5', displayName: 'Five', accessibilityLabel: 'Five'),
    VisualSymbol(id: 'num_6', glyph: '6', displayName: 'Six', accessibilityLabel: 'Six'),
  ],
);
