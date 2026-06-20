import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../grid/box_shape.dart';
import '../../grid/grid_dimensions.dart';
import 'daily_puzzle.dart';
import 'manual_puzzle.dart';

/// Loads the pre-generated level pool (`assets/levels/runic_sudoku_levels.json`,
/// Phase 2) and exposes it as in-memory [ManualPuzzle]s.
///
/// The pool entries have no `level_id` (the Phase 2 `LevelData` schema omits it),
/// so a STABLE id is derived from the entry's position: `rs_000`, `rs_001`, …
/// This is the canonical id used for save slots, completion tracking, and daily
/// selection. See PHASE3_NOTES.md "Specification ambiguities".
class LevelPool {
  final List<ManualPuzzle> levels;

  const LevelPool(this.levels);

  static const String assetPath = 'assets/levels/runic_sudoku_levels.json';

  /// Display order for difficulty groupings.
  static const List<String> labelOrder = ['Quick', 'Normal', 'Tricky', 'Deep'];

  /// Loads + parses the bundled asset. Call once at app start (needs the Flutter
  /// binding initialized for `rootBundle`).
  static Future<LevelPool> loadFromAsset({String path = assetPath}) async {
    final raw = await rootBundle.loadString(path);
    return LevelPool.fromJsonString(raw);
  }

  /// Pure parse from a JSON string — used by tests (no `rootBundle`).
  factory LevelPool.fromJsonString(String jsonString) {
    final doc = jsonDecode(jsonString) as Map<String, dynamic>;
    final entries = doc['levels'] as List;
    return LevelPool([
      for (var i = 0; i < entries.length; i++)
        _puzzleFromEntry(entries[i] as Map<String, dynamic>, i),
    ]);
  }

  static String levelIdForIndex(int index) =>
      'rs_${index.toString().padLeft(3, '0')}';

  static ManualPuzzle _puzzleFromEntry(Map<String, dynamic> e, int index) {
    List<List<int>> grid(dynamic raw) => [
          for (final row in (raw as List))
            [for (final v in (row as List)) (v as num).toInt()],
        ];
    final est = e['estimated_solve_time'];
    return ManualPuzzle(
      levelId: levelIdForIndex(index),
      seed: (e['seed'] as num?)?.toInt() ?? 0,
      gridSize: GridDimensions.parse(e['grid_size'] as String),
      boxShape: BoxShape.parse(e['box_shape'] as String),
      solutionGrid: grid(e['solution_grid']),
      givenCells: grid(e['given_cells']),
      difficultyLabel: e['difficulty_label'] as String,
      estimatedSolveTime: est == null
          ? Duration.zero
          : Duration(milliseconds: (est as num).toInt()),
    );
  }

  int get length => levels.length;

  List<ManualPuzzle> byLabel(String label) =>
      [for (final l in levels) if (l.difficultyLabel == label) l];

  /// Labels that actually appear in the pool, in [labelOrder].
  List<String> get presentLabels {
    final present = {for (final l in levels) l.difficultyLabel};
    return [for (final l in labelOrder) if (present.contains(l)) l];
  }

  ManualPuzzle? byId(String id) {
    for (final l in levels) {
      if (l.levelId == id) return l;
    }
    return null;
  }

  /// The deterministic daily puzzle for [date] (local calendar date).
  ManualPuzzle dailyFor(DateTime date) =>
      levels[DailyPuzzleSelector.indexForDate(date, levels.length)];
}
