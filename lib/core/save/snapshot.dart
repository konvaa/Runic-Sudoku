/// Base contract for any game's complete-state snapshot.
///
/// App Core only knows that a snapshot can identify its save slot and serialize
/// itself to JSON. It deliberately cannot reconstruct a typed snapshot — that
/// requires game-specific knowledge, so [SaveService.load] returns raw JSON and
/// the game module deserializes it (e.g. `RunicSudokuSnapshot.fromJson`).
abstract class Snapshot {
  /// Stable identifier of the game producing this snapshot (e.g. "runic_sudoku").
  String get gameId;

  /// Identifier of the specific level/puzzle.
  String get levelId;

  /// Slot key under which this snapshot is stored. Defaults to one slot per
  /// (game, level). Override if a game needs a different scheme.
  String get saveKey => '$gameId/$levelId';

  Map<String, dynamic> toJson();
}
