import 'grid_coordinate.dart';

/// A presentation-only view model for one rendered cell.
///
/// Grid Core renders these; it does not compute them. The game module (e.g.
/// Runic Sudoku) decides what counts as `isGiven`, `hasError`, etc. and produces
/// a list of `GridCell`s for the board to draw. This keeps all rule knowledge
/// out of Grid Core.
class GridCell {
  final GridCoordinate coordinate;

  /// Primary glyph/text to render large in the cell (e.g. a rune). Null = empty.
  final String? primaryText;

  /// Small candidate marks to render in a corner grid (notes). May be empty.
  final List<String> noteMarks;

  /// Locked clue cell — typically rendered with emphasis and not editable.
  final bool isGiven;

  /// The user-selected cell.
  final bool isSelected;

  /// Peer highlight (e.g. same row/col/box or same value) — purely visual.
  final bool isHighlighted;

  /// Conflict/wrong-value flag — purely visual; the game decides the meaning.
  final bool hasError;

  const GridCell({
    required this.coordinate,
    this.primaryText,
    this.noteMarks = const [],
    this.isGiven = false,
    this.isSelected = false,
    this.isHighlighted = false,
    this.hasError = false,
  });

  GridCell copyWith({
    String? primaryText,
    List<String>? noteMarks,
    bool? isGiven,
    bool? isSelected,
    bool? isHighlighted,
    bool? hasError,
  }) {
    return GridCell(
      coordinate: coordinate,
      primaryText: primaryText ?? this.primaryText,
      noteMarks: noteMarks ?? this.noteMarks,
      isGiven: isGiven ?? this.isGiven,
      isSelected: isSelected ?? this.isSelected,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      hasError: hasError ?? this.hasError,
    );
  }
}
