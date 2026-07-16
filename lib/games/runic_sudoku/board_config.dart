import '../../grid/box_shape.dart';
import '../../grid/grid_dimensions.dart';

/// The identity of a playable board: grid dimensions, box subdivision, and the
/// number of distinct rune values. Introduced by the chapter-system refactor
/// (see dev_notes/fable_step0_inventory_result.md) so board identity travels
/// as ONE explicit, compiler-checked value instead of implicit 6×6 defaults.
///
/// For a square sudoku board [runeCount] must equal `dimensions.cols`
/// (6×6 → 6, 9×9 → 9). This cannot be asserted in the const constructor (a
/// const initializer cannot read `dimensions.cols`), so [debugAssertValid] is
/// checked by consumers that receive a config at runtime.
///
/// Pure Dart and JSON-serializable, so it can cross an isolate `compute()`
/// boundary (used by the Free Play generation payload).
class BoardConfig {
  final GridDimensions dimensions;
  final BoxShape boxShape;

  /// Number of distinct rune values (1..runeCount) legal on this board.
  final int runeCount;

  const BoardConfig({
    required this.dimensions,
    required this.boxShape,
    required this.runeCount,
  });

  /// Chapter 1's board: 6×6 grid, 2×3 boxes, 6 runes. The only board shipped
  /// today; every production call site passes this explicitly.
  static const sixBySix = BoardConfig(
    dimensions: GridDimensions(rows: 6, cols: 6),
    boxShape: BoxShape(rows: 2, cols: 3),
    runeCount: 6,
  );

  /// True when the config is internally consistent: boxes tile the grid and
  /// the rune count matches the column count (square sudoku convention).
  bool get isValid =>
      boxShape.fits(dimensions) && runeCount == dimensions.cols;

  /// Asserts [isValid] in debug builds; returns this for call-site chaining.
  BoardConfig debugAssertValid() {
    assert(isValid, 'Invalid BoardConfig: $this');
    return this;
  }

  /// Wire form uses the established Phase 0 tokens ("6x6", "2x3").
  Map<String, dynamic> toJson() => {
        'grid_size': dimensions.toToken(),
        'box_shape': boxShape.toToken(),
        'rune_count': runeCount,
      };

  factory BoardConfig.fromJson(Map<String, dynamic> json) => BoardConfig(
        dimensions: GridDimensions.parse(json['grid_size'] as String),
        boxShape: BoxShape.parse(json['box_shape'] as String),
        runeCount: (json['rune_count'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is BoardConfig &&
      other.dimensions == dimensions &&
      other.boxShape == boxShape &&
      other.runeCount == runeCount;

  @override
  int get hashCode => Object.hash(dimensions, boxShape, runeCount);

  @override
  String toString() =>
      'BoardConfig(${dimensions.toToken()}, box ${boxShape.toToken()}, '
      '$runeCount runes)';
}
