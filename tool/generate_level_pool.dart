// Offline level-pool generator (pure Dart — run from the project root with:
//   dart run tool/generate_level_pool.dart
//
// Pre-generates a static pool of puzzles per difficulty label and writes them to
// assets/levels/runic_sudoku_levels.json using the existing LevelData export
// format (plus estimated_solve_time). This is BUILD-TIME tooling: the 6×6 MVP
// ships this static pool and reads from it, rather than generating on-device.
// Runtime generation (PuzzleGenerator) is unchanged and remains available for
// future use (e.g. daily puzzles, or 9×9).
//
// Deep is the costly label on 6×6 (it lives at near-minimal puzzles, ~26–28
// blanks, complexity >= 0.30), so it uses a much higher maxAttempts here — the
// cost is paid once, offline, not on the player's device.

import 'dart:convert';
import 'dart:io';

import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';

/// (label, count, maxAttempts) per label. Counts are a reference MVP pool, not
/// final content — tweak as needed.
const _plan = <(DifficultyLabel, int, int)>[
  (DifficultyLabel.quick, 20, 60),
  (DifficultyLabel.normal, 30, 60),
  (DifficultyLabel.tricky, 30, 80),
  (DifficultyLabel.deep, 20, 300),
];

void main() {
  final generator = PuzzleGenerator();
  final levels = <Map<String, dynamic>>[];

  for (final (label, count, maxAttempts) in _plan) {
    final seen = <String>{};
    var got = 0;
    var seed = 0;
    var attemptsTotal = 0;

    while (got < count && seed < count * 400) {
      seed++;
      try {
        final r = generator.generate(
          target: label,
          seed: 10000 + seed * 131,
          maxAttempts: maxAttempts,
        );
        final key = r.level.givenCells.toString();
        if (!seen.add(key)) continue; // skip duplicates
        levels.add(r.level.toJson());
        got++;
        attemptsTotal += r.attempts;
      } on StateError {
        // band not reached within maxAttempts this seed; try another
      }
    }

    stdout.writeln('${label.token.padRight(7)} generated $got/$count  '
        'avgAttempts=${got == 0 ? '-' : (attemptsTotal / got).toStringAsFixed(1)}');
  }

  final counts = <String, int>{};
  for (final l in levels) {
    final lab = l['difficulty_label'] as String;
    counts[lab] = (counts[lab] ?? 0) + 1;
  }

  final doc = <String, dynamic>{
    'schema': 'runic_sudoku_level_pool_v1',
    'note': 'Pre-generated reference level pool for the 6x6 Runic Sudoku MVP. '
        'Each entry is the LevelData JSON plus estimated_solve_time (ms). '
        'Canonical data is solution_grid + given_cells; seed is debug-only.',
    'grid_size': '6x6',
    'box_shape': '2x3',
    'counts': counts,
    'levels': levels,
  };

  Directory('assets/levels').createSync(recursive: true);
  final file = File('assets/levels/runic_sudoku_levels.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(doc));
  stdout.writeln('Wrote ${levels.length} levels to ${file.path}');
}
