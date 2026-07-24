import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../grid/box_shape.dart';
import '../../grid/grid_dimensions.dart';
import 'daily_puzzle.dart';
import 'manual_puzzle.dart';

/// Loads the pre-generated level pool (`assets/levels/runic_sudoku_levels.json`)
/// and exposes it as in-memory [ManualPuzzle]s.
///
/// Two pool schema versions are supported (dispatch on the envelope's
/// `schema_version` field):
///
/// * **Version 0 (legacy)** — no `schema_version` field. Entries carry no
///   `level_id`; a stable id is derived from the entry's position: `rs_000`,
///   `rs_001`, … (the original Phase 2/3 behaviour, kept so that legacy pool
///   data and test fixtures continue to load unchanged).
/// * **Version 1 (explicit ids)** — the envelope carries `schema_version: 1`
///   and every entry stores an explicit `level_id`, which is the durable
///   identity. Array position does NOT determine identity: a missing, empty, or
///   duplicate `level_id` is a hard parse error (no positional fallback), and
///   ids are treated as opaque strings (no required shape).
///
/// The level id is the canonical id used for save slots, completion tracking,
/// and daily selection. The shipped Chapter 1 asset stores explicit ids equal
/// to its historical positional mapping (`rs_000`…`rs_099`), so identity is
/// unchanged for existing players. See docs/chapter1_schema_freeze_result.md.
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
    final schemaVersion = (doc['schema_version'] as num?)?.toInt() ?? 0;
    final entries = doc['levels'] as List;
    switch (schemaVersion) {
      case 0:
        // Legacy pool: no explicit ids; identity is derived from position,
        // exactly as before the schema freeze.
        return LevelPool([
          for (var i = 0; i < entries.length; i++)
            _puzzleFromEntry(
                entries[i] as Map<String, dynamic>, levelIdForIndex(i)),
        ]);
      case 1:
        // Explicit-id pool: every entry must carry a non-empty, unique
        // level_id. No positional fallback — a bad id is a parse error.
        final seen = <String>{};
        final levels = <ManualPuzzle>[];
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i] as Map<String, dynamic>;
          final id = e['level_id'];
          if (id is! String || id.isEmpty) {
            throw FormatException(
                'Level pool schema_version 1: entry $i has a missing or '
                'empty level_id');
          }
          if (!seen.add(id)) {
            throw FormatException(
                'Level pool schema_version 1: duplicate level_id "$id" '
                '(entry $i)');
          }
          levels.add(_puzzleFromEntry(e, id));
        }
        return LevelPool(levels);
      default:
        throw FormatException(
            'Unsupported level pool schema_version: $schemaVersion');
    }
  }

  /// The historical positional id (`rs_000`, `rs_001`, …). Used to derive ids
  /// for legacy (schema version 0) pools; for schema version 1 pools ids are
  /// read from the file instead.
  static String levelIdForIndex(int index) =>
      'rs_${index.toString().padLeft(3, '0')}';

  static ManualPuzzle _puzzleFromEntry(Map<String, dynamic> e, String levelId) {
    List<List<int>> grid(dynamic raw) => [
          for (final row in (raw as List))
            [for (final v in (row as List)) (v as num).toInt()],
        ];
    final est = e['estimated_solve_time'];
    return ManualPuzzle(
      levelId: levelId,
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
