import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../generator/level_data.dart';
import '../manual_puzzle.dart';

/// One Deep Free Play puzzle plus its stable [puzzleId] (used for "already seen"
/// deduplication). Bundled-pool ids are `deep_fp_NNN`; rolling-cache ids are a
/// hash of the given cells (see [deepIdFromGiven]).
class DeepPuzzleEntry {
  final String puzzleId;
  final LevelData data;

  const DeepPuzzleEntry({required this.puzzleId, required this.data});

  Map<String, dynamic> toJson() => {
        'puzzle_id': puzzleId,
        ...data.toJson(),
      };

  factory DeepPuzzleEntry.fromJson(Map<String, dynamic> json) {
    final data = LevelData.fromJson(json);
    final id = json['puzzle_id'] as String? ?? deepIdFromGiven(data.givenCells);
    return DeepPuzzleEntry(puzzleId: id, data: data);
  }

  /// Builds the playable puzzle. All Free Play sessions share one save slot id
  /// (`active_freeplay`); Phase 3.66.2 resumes it instead of always starting
  /// fresh.
  ManualPuzzle toManualPuzzle({String levelId = 'active_freeplay'}) =>
      ManualPuzzle(
        levelId: levelId,
        seed: data.seed ?? 0,
        gridSize: data.gridSize,
        boxShape: data.boxShape,
        solutionGrid: data.solutionGrid,
        givenCells: data.givenCells,
        difficultyLabel: data.difficultyLabel,
        estimatedSolveTime: data.estimatedSolveTime ?? Duration.zero,
      );
}

/// Stable id for a generated (cache) puzzle: FNV-1a hash of the given cells.
/// Same givens → same id, so a regenerated duplicate is recognised.
String deepIdFromGiven(List<List<int>> given) {
  final s = given.map((r) => r.join(',')).join('|');
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return 'deep_c_${h.toRadixString(16).padLeft(8, '0')}';
}

/// Loads the read-only bundled Deep pool (`assets/freeplay/deep_pool.json`).
class DeepBundledPool {
  const DeepBundledPool._();

  static const String assetPath = 'assets/freeplay/deep_pool.json';

  /// Loads + parses the bundled asset. A missing/unparseable asset yields an
  /// empty list rather than throwing, so the app still runs (the rolling cache
  /// then carries Free Play Deep on its own).
  static Future<List<DeepPuzzleEntry>> loadFromAsset({
    String path = assetPath,
  }) async {
    try {
      return fromJsonString(await rootBundle.loadString(path));
    } catch (_) {
      return const <DeepPuzzleEntry>[];
    }
  }

  /// Pure parse from a JSON string — used by tests (no `rootBundle`).
  static List<DeepPuzzleEntry> fromJsonString(String jsonString) {
    final doc = jsonDecode(jsonString) as Map<String, dynamic>;
    final entries = doc['puzzles'] as List;
    return [
      for (final e in entries) DeepPuzzleEntry.fromJson(e as Map<String, dynamic>),
    ];
  }
}
