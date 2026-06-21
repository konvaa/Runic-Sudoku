// Generator audit / diagnostic (pure Dart — run from the project root with:
//   dart run tool/generator_audit.dart
//
// Generates a batch of puzzles per difficulty label and reports generation
// speed, rejection rate, puzzle-quality distributions, duplicate rate, and a
// Free-Play viability verdict. It also writes 5 random samples per label to
// tool/audit_samples.json for manual inspection.
//
// DIAGNOSTIC ONLY — it does not modify any production code; it just calls the
// existing PuzzleGenerator. Deep is the slow label; 200 Deep puzzles may take a
// few minutes.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';

const int perLabel = 200; // puzzles generated per label
const int sampleCount = 5; // samples exported per label

// Generation attempt budget per label (Deep needs many more; offline cost).
const Map<DifficultyLabel, int> _maxAttempts = {
  DifficultyLabel.quick: 200,
  DifficultyLabel.normal: 200,
  DifficultyLabel.tricky: 400,
  DifficultyLabel.deep: 800,
};

// Free Play mode (`dart run tool/generator_audit.dart freeplay`): generate with
// the on-demand FreePlayGuardrails enabled. Deep gets extra headroom because the
// guardrails reject more near-minimal puzzles.
const Map<DifficultyLabel, int> _maxAttemptsFreePlay = {
  DifficultyLabel.quick: 200,
  DifficultyLabel.normal: 200,
  DifficultyLabel.tricky: 400,
  DifficultyLabel.deep: 1200,
};

// Free-Play thresholds (see assessment at the end).
const double _fastP95SecondsEasy = 2.0; // Quick / Normal
const double _fastP95SecondsHard = 5.0; // Tricky / Deep
const double _maxRejectsP95 = 100.0;

void main(List<String> args) {
  final freePlay = args.contains('freeplay');
  final budgets = freePlay ? _maxAttemptsFreePlay : _maxAttempts;
  final generator = PuzzleGenerator();
  final rng = Random(20260618);

  stdout.writeln(freePlay
      ? '** FREE PLAY MODE: generating with FreePlayGuardrails enabled **\n'
      : '** CAMPAIGN MODE (no guardrails) **\n');

  final samples = <String, List<Map<String, dynamic>>>{};
  final perLabelSummary = <DifficultyLabel, _LabelSummary>{};

  for (final label in DifficultyLabel.values) {
    stdout.writeln('Generating $perLabel ${label.token} puzzles '
        '(maxAttempts=${budgets[label]}) ...');

    final times = <double>[]; // ms per puzzle
    final rejects = <double>[]; // attempts - 1
    final est = <double>[]; // seconds
    final complexity = <double>[];
    final decisions = <double>[];
    final forced = <double>[];
    final generated = <Map<String, dynamic>>[];
    final givenPatterns = <String>{};
    var duplicates = 0;
    var unsupported = 0;
    var failures = 0;

    final sw = Stopwatch();
    for (var i = 0; i < perLabel; i++) {
      // Space base seeds well beyond the internal sweep so puzzles differ.
      final seed = i * 100000 + label.index * 7;
      sw.reset();
      sw.start();
      try {
        final r = generator.generate(
          target: label,
          seed: seed,
          maxAttempts: budgets[label]!,
          freePlay: freePlay,
        );
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
        rejects.add((r.attempts - 1).toDouble());
        est.add(r.metrics.estimatedSolveTime.inMilliseconds / 1000.0);
        complexity.add(r.metrics.candidateComplexity);
        decisions.add(r.metrics.decisionPointsCount.toDouble());
        forced.add(r.metrics.forcedMovesCount.toDouble());
        if (r.metrics.unsupportedTechnique) unsupported++;
        if (!givenPatterns.add(r.level.givenCells.toString())) duplicates++;
        generated.add({
          'solution_grid': r.level.solutionGrid,
          'given_cells': r.level.givenCells,
          'difficulty_label': r.level.difficultyLabel,
          'estimated_solve_time': r.metrics.estimatedSolveTime.inMilliseconds,
          'candidate_complexity': r.metrics.candidateComplexity,
          'decision_points_count': r.metrics.decisionPointsCount,
          'forced_moves_count': r.metrics.forcedMovesCount,
        });
      } on StateError {
        sw.stop();
        failures++;
      }
    }

    // ---- report ----
    stdout.writeln('');
    stdout.writeln('=== ${label.token}  '
        '(${generated.length}/$perLabel generated, $failures failed) ===');
    _dist('gen time (ms)', times);
    _dist('rejected/puzzle', rejects);
    _dist('estimated_solve (s)', est);
    _dist('candidate_complexity', complexity, decimals: 3);
    _dist('decision_points', decisions);
    _dist('forced_moves', forced);
    stdout.writeln('  duplicates: $duplicates    '
        'unsupported_technique: $unsupported');
    stdout.writeln('');

    final shuffled = [...generated]..shuffle(rng);
    samples[label.token] = shuffled.take(sampleCount).toList();

    perLabelSummary[label] = _LabelSummary(
      generated: generated.length,
      failures: failures,
      duplicates: duplicates,
      unsupported: unsupported,
      timeP95: _pct(times, 0.95),
      rejectP95: _pct(rejects, 0.95),
      estAvg: _avg(est),
    );
  }

  // ---- write samples ----
  final file = File('tool/audit_samples.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(samples));
  stdout.writeln('Wrote samples to ${file.path}');
  stdout.writeln('');

  _assessment(perLabelSummary);
}

void _assessment(Map<DifficultyLabel, _LabelSummary> s) {
  stdout.writeln('================ FREE PLAY VIABILITY ================');

  String mark(bool b) => b ? 'PASS' : 'FAIL';

  for (final label in [DifficultyLabel.quick, DifficultyLabel.normal]) {
    final p95 = s[label]!.timeP95;
    stdout.writeln('${mark(p95 < _fastP95SecondsEasy * 1000)}  '
        '${label.token} gen P95 = ${(p95 / 1000).toStringAsFixed(2)}s '
        '(< ${_fastP95SecondsEasy}s ?)');
  }
  for (final label in [DifficultyLabel.tricky, DifficultyLabel.deep]) {
    final p95 = s[label]!.timeP95;
    stdout.writeln('${mark(p95 < _fastP95SecondsHard * 1000)}  '
        '${label.token} gen P95 = ${(p95 / 1000).toStringAsFixed(2)}s '
        '(< ${_fastP95SecondsHard}s ?)');
  }

  final rejectsOk = s.values.every((v) => v.rejectP95 <= _maxRejectsP95);
  stdout.writeln('${mark(rejectsOk)}  rejection P95 <= $_maxRejectsP95 for all '
      'labels (${s.entries.map((e) => '${e.key.token}:${e.value.rejectP95.toStringAsFixed(0)}').join(', ')})');

  final noDupes = s.values.every((v) => v.duplicates == 0);
  stdout.writeln('${mark(noDupes)}  no duplicates '
      '(${s.entries.map((e) => '${e.key.token}:${e.value.duplicates}').join(', ')})');

  final noUnsupported = s.values.every((v) => v.unsupported == 0);
  stdout.writeln('${mark(noUnsupported)}  no unsupported_technique puzzles '
      '(${s.entries.map((e) => '${e.key.token}:${e.value.unsupported}').join(', ')})');

  final noFailures = s.values.every((v) => v.failures == 0);
  stdout.writeln('${mark(noFailures)}  no generation failures '
      '(${s.entries.map((e) => '${e.key.token}:${e.value.failures}').join(', ')})');

  final estList = [
    s[DifficultyLabel.quick]!.estAvg,
    s[DifficultyLabel.normal]!.estAvg,
    s[DifficultyLabel.tricky]!.estAvg,
    s[DifficultyLabel.deep]!.estAvg,
  ];
  var monotone = true;
  for (var i = 1; i < estList.length; i++) {
    if (estList[i] <= estList[i - 1]) monotone = false;
  }
  stdout.writeln('${mark(monotone)}  estimated_solve_time increases '
      'Quick<Normal<Tricky<Deep '
      '(${estList.map((e) => e.toStringAsFixed(0)).join(' < ')} s)');

  stdout.writeln('====================================================');
}

// ---- helpers ----

class _LabelSummary {
  final int generated;
  final int failures;
  final int duplicates;
  final int unsupported;
  final double timeP95; // ms
  final double rejectP95;
  final double estAvg; // seconds
  _LabelSummary({
    required this.generated,
    required this.failures,
    required this.duplicates,
    required this.unsupported,
    required this.timeP95,
    required this.rejectP95,
    required this.estAvg,
  });
}

double _avg(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

double _pct(List<double> xs, double p) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  return s[((s.length - 1) * p).round()];
}

void _dist(String name, List<double> xs, {int decimals = 1}) {
  if (xs.isEmpty) {
    stdout.writeln('  ${name.padRight(22)} (none)');
    return;
  }
  final s = [...xs]..sort();
  String f(double v) => v.toStringAsFixed(decimals);
  stdout.writeln('  ${name.padRight(22)} '
      'min=${f(s.first)} avg=${f(_avg(s))} P50=${f(_pct(s, .5))} '
      'P95=${f(_pct(s, .95))} P99=${f(_pct(s, .99))} max=${f(s.last)}');
}
