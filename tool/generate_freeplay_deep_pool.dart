// Generates the bundled Deep Free Play starting pool (Phase 3.66.1).
//
//   dart run tool/generate_freeplay_deep_pool.dart
//
// Produces 75 Deep puzzles WITH the Free Play guardrails (`freePlay: true`) and
// writes them to assets/freeplay/deep_pool.json, each tagged `deep_fp_NNN`.
// Deduplicates by given-cell pattern and prints progress + rejection/time stats.
//
// This is an offline asset builder (not shipped code). Deep with guardrails is
// expensive, so the whole run can take a few minutes.

import 'dart:convert';
import 'dart:io';

import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';

const int poolSize = 75;
const int maxAttemptsPerPuzzle = 2500;
const String outPath = 'assets/freeplay/deep_pool.json';

void main() {
  // Deep Free Play pool: explicitly the 6×6 board (matches the shipped asset).
  final generator = PuzzleGenerator(board: BoardConfig.sixBySix);
  final puzzles = <Map<String, dynamic>>[];
  final seenGivens = <String>{};
  final rejections = <int>[];
  final times = <int>[]; // ms

  final sw = Stopwatch()..start();
  var seed = 13579;
  var failures = 0;

  while (puzzles.length < poolSize) {
    final t0 = sw.elapsedMicroseconds;
    GenerationResult r;
    try {
      r = generator.generate(
        target: DifficultyLabel.deep,
        seed: seed++,
        maxAttempts: maxAttemptsPerPuzzle,
        freePlay: true,
      );
    } on StateError {
      failures++;
      continue;
    }
    final genMs = ((sw.elapsedMicroseconds - t0) / 1000).round();

    final key = r.level.givenCells.toString();
    if (!seenGivens.add(key)) continue; // duplicate pattern — skip

    final i = puzzles.length;
    puzzles.add({
      'puzzle_id': 'deep_fp_${i.toString().padLeft(3, '0')}',
      'grid_size': r.level.gridSize.toToken(),
      'box_shape': r.level.boxShape.toToken(),
      'solution_grid': r.level.solutionGrid,
      'given_cells': r.level.givenCells,
      'difficulty_label': r.level.difficultyLabel,
      'estimated_solve_time': r.metrics.estimatedSolveTime.inMilliseconds,
      'candidate_complexity':
          double.parse(r.metrics.candidateComplexity.toStringAsFixed(4)),
    });
    rejections.add(r.attempts - 1);
    times.add(genMs);

    stdout.writeln('#${puzzles.length}/$poolSize  '
        'attempts=${r.attempts}  '
        'complexity=${r.metrics.candidateComplexity.toStringAsFixed(3)}  '
        '${genMs}ms  (elapsed ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(0)}s)');
  }
  sw.stop();

  final file = File(outPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'puzzles': puzzles}));

  double avg(List<int> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  stdout.writeln('');
  stdout.writeln('Wrote ${puzzles.length} puzzles to $outPath');
  stdout.writeln('rejections: avg=${avg(rejections).toStringAsFixed(1)}  '
      'max=${rejections.reduce((a, b) => a > b ? a : b)}');
  stdout.writeln('gen time:   avg=${avg(times).toStringAsFixed(0)}ms  '
      'max=${times.reduce((a, b) => a > b ? a : b)}ms');
  stdout.writeln('failures (maxAttempts exhausted): $failures');
}
