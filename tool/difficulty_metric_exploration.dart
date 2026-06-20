// Difficulty-metric exploration (pure Dart — run with:
//   dart run tool/difficulty_metric_exploration.dart
//
// PURPOSE: a MEASUREMENT/diagnostic experiment, not a production change. It does
// NOT touch HumanLikeSolver or DifficultyScorer. It uses its own self-contained
// "pure-single" probe solver (naked + hidden singles only, no solution
// assistance) so we can observe, across the full blank-fraction range, whether a
// stall actually occurs on 6×6 and how several candidate difficulty metrics
// behave. None of these metrics are wired into the app; this only prints numbers
// for us to compare before deciding anything.
//
// It answers the four questions from the brief:
//   1. true stall rate per blank fraction (does "needs more than singles" ever
//      happen on 6×6?);
//   2. alternative metrics that don't depend on stalls: solving step count,
//      hidden-single ratio, peak candidates-per-cell, and (for reference) the
//      Phase 0 candidate_complexity;
//   3. how each metric correlates with blank fraction (Pearson r over the sweep);
//   4. raw material for the recommendation (see PHASE2_NOTES.md follow-up).

import 'dart:math';

import 'package:runic_sudoku/games/runic_sudoku/generator/cell_removal.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/full_grid_generator.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

const dims = GridDimensions(rows: 6, cols: 6);
const box = BoxShape(rows: 2, cols: 3);
const samples = 100;

void main() {
  final full = FullGridGenerator(dimensions: dims, boxShape: box);
  final remover = CellRemover(dimensions: dims, boxShape: box);
  final cellCount = dims.cellCount;

  final fractions = <double>[];
  for (var f = 20; f <= 70; f += 5) {
    fractions.add(f / 100.0);
  }

  print('Grid ${dims.toToken()} / box ${box.toToken()},  $samples carved, '
      'unique puzzles per fraction (pre-rejection).');
  print('Probe = naked+hidden singles only, NO solution assistance.');
  print('');
  print(_row([
    'frac',
    'tgtBlank',
    'avgBlank',
    'stall%',
    'avgSteps',
    'hiddenRatio',
    'maxCands',
    'mcSD',
    'complexity',
    'cplxSD',
  ]));
  print('-' * 96);

  final fracX = <double>[];
  final stallY = <double>[];
  final stepsY = <double>[];
  final hiddenY = <double>[];
  final maxCandY = <double>[];
  final complexY = <double>[];

  for (final frac in fractions) {
    final targetBlanks = (cellCount * frac).round();
    var stalls = 0;
    var stepSum = 0;
    var hiddenRatioSum = 0.0;
    var maxCandSum = 0;
    var maxCandSqSum = 0.0;
    var complexSum = 0.0;
    var complexSqSum = 0.0;
    var blankSum = 0;

    for (var i = 0; i < samples; i++) {
      final rng = Random(900000 + (frac * 100).round() * 1009 + i);
      final grid = full.generate(rng);
      final puzzle =
          remover.remove(grid, rng, targetBlanks: targetBlanks);
      final r = _probe(puzzle);

      if (!r.solvedBySingles) stalls++;
      stepSum += r.steps;
      hiddenRatioSum += r.hiddenRatio;
      maxCandSum += r.maxCandidates;
      maxCandSqSum += (r.maxCandidates * r.maxCandidates).toDouble();
      complexSum += r.initialComplexity;
      complexSqSum += r.initialComplexity * r.initialComplexity;
      blankSum += _blanks(puzzle);
    }

    final stallRate = 100.0 * stalls / samples;
    final avgSteps = stepSum / samples;
    final avgHidden = hiddenRatioSum / samples;
    final avgMaxCand = maxCandSum / samples;
    final avgComplex = complexSum / samples;
    final avgBlank = blankSum / samples;
    // Standard deviation reveals whether adjacent label bands are separated by
    // more than the within-fraction spread (the noise-vs-gap question).
    final complexSD = _stddev(complexSum, complexSqSum, samples);
    final maxCandSD = _stddev(maxCandSum.toDouble(), maxCandSqSum, samples);

    print(_row([
      frac.toStringAsFixed(2),
      '$targetBlanks',
      avgBlank.toStringAsFixed(1),
      stallRate.toStringAsFixed(1),
      avgSteps.toStringAsFixed(1),
      avgHidden.toStringAsFixed(3),
      avgMaxCand.toStringAsFixed(2),
      maxCandSD.toStringAsFixed(2),
      avgComplex.toStringAsFixed(3),
      complexSD.toStringAsFixed(3),
    ]));

    fracX.add(frac);
    stallY.add(stallRate);
    stepsY.add(avgSteps);
    hiddenY.add(avgHidden);
    maxCandY.add(avgMaxCand);
    complexY.add(avgComplex);
  }

  print('');
  print('Pearson r vs blank fraction (1.0 = perfectly monotone-increasing):');
  print('  stall_rate       : ${_pearson(fracX, stallY).toStringAsFixed(3)}');
  print('  solving_steps    : ${_pearson(fracX, stepsY).toStringAsFixed(3)}');
  print('  hidden_ratio     : ${_pearson(fracX, hiddenY).toStringAsFixed(3)}');
  print('  max_candidates   : ${_pearson(fracX, maxCandY).toStringAsFixed(3)}');
  print('  candidate_complex: ${_pearson(fracX, complexY).toStringAsFixed(3)}');
}

// ---- Self-contained pure-single probe -------------------------------------

class _ProbeResult {
  final bool solvedBySingles;
  final int steps; // naked + hidden placements actually made
  final int nakedCount;
  final int hiddenCount;
  final int maxCandidates; // peak candidate-set size seen during solving
  final double initialComplexity; // Phase 0 candidate_complexity of the givens

  _ProbeResult({
    required this.solvedBySingles,
    required this.steps,
    required this.nakedCount,
    required this.hiddenCount,
    required this.maxCandidates,
    required this.initialComplexity,
  });

  double get hiddenRatio => steps == 0 ? 0 : hiddenCount / steps;
}

_ProbeResult _probe(List<List<int>> given) {
  final board = [for (final row in given) List<int>.from(row)];
  final initialComplexity = _complexity(_candidates(board));

  var steps = 0;
  var naked = 0;
  var hidden = 0;
  var maxCands = 0;

  while (true) {
    final cands = _candidates(board);
    if (cands.isEmpty) {
      return _ProbeResult(
        solvedBySingles: true,
        steps: steps,
        nakedCount: naked,
        hiddenCount: hidden,
        maxCandidates: maxCands,
        initialComplexity: initialComplexity,
      );
    }
    for (final s in cands.values) {
      if (s.length > maxCands) maxCands = s.length;
      if (s.isEmpty) {
        // contradiction: unsolvable by singles (counts as a stall)
        return _ProbeResult(
          solvedBySingles: false,
          steps: steps,
          nakedCount: naked,
          hiddenCount: hidden,
          maxCandidates: maxCands,
          initialComplexity: initialComplexity,
        );
      }
    }

    final nk = _firstNaked(cands);
    if (nk != null) {
      board[nk.$1.row][nk.$1.col] = nk.$2;
      steps++;
      naked++;
      continue;
    }
    final hd = _firstHidden(cands);
    if (hd != null) {
      board[hd.$1.row][hd.$1.col] = hd.$2;
      steps++;
      hidden++;
      continue;
    }
    // Stall: neither single available, not solved.
    return _ProbeResult(
      solvedBySingles: false,
      steps: steps,
      nakedCount: naked,
      hiddenCount: hidden,
      maxCandidates: maxCands,
      initialComplexity: initialComplexity,
    );
  }
}

Map<GridCoordinate, Set<int>> _candidates(List<List<int>> board) {
  final n = dims.cols;
  final rowUsed = List<Set<int>>.generate(dims.rows, (r) {
    final s = <int>{};
    for (var c = 0; c < dims.cols; c++) {
      if (board[r][c] != 0) s.add(board[r][c]);
    }
    return s;
  });
  final colUsed = List<Set<int>>.generate(dims.cols, (c) {
    final s = <int>{};
    for (var r = 0; r < dims.rows; r++) {
      if (board[r][c] != 0) s.add(board[r][c]);
    }
    return s;
  });
  final boxUsed = List<Set<int>>.generate(box.boxCount(dims), (b) {
    final s = <int>{};
    for (final coord in box.coordinatesInBox(b, dims)) {
      final v = board[coord.row][coord.col];
      if (v != 0) s.add(v);
    }
    return s;
  });

  final result = <GridCoordinate, Set<int>>{};
  for (var r = 0; r < dims.rows; r++) {
    for (var c = 0; c < dims.cols; c++) {
      if (board[r][c] != 0) continue;
      final coord = GridCoordinate(r, c);
      final b = box.boxIndexFor(coord, dims);
      final cand = <int>{};
      for (var v = 1; v <= n; v++) {
        if (!rowUsed[r].contains(v) &&
            !colUsed[c].contains(v) &&
            !boxUsed[b].contains(v)) {
          cand.add(v);
        }
      }
      result[coord] = cand;
    }
  }
  return result;
}

(GridCoordinate, int)? _firstNaked(Map<GridCoordinate, Set<int>> cands) {
  for (final e in cands.entries) {
    if (e.value.length == 1) return (e.key, e.value.first);
  }
  return null;
}

(GridCoordinate, int)? _firstHidden(Map<GridCoordinate, Set<int>> cands) {
  final n = dims.cols;
  List<(GridCoordinate, int)?> scan(List<GridCoordinate> unit) {
    final hits = <(GridCoordinate, int)?>[];
    for (var v = 1; v <= n; v++) {
      GridCoordinate? home;
      var count = 0;
      for (final coord in unit) {
        final s = cands[coord];
        if (s != null && s.contains(v)) {
          count++;
          home = coord;
          if (count > 1) break;
        }
      }
      if (count == 1) hits.add((home!, v));
    }
    return hits;
  }

  for (var r = 0; r < dims.rows; r++) {
    final h = scan([for (var c = 0; c < dims.cols; c++) GridCoordinate(r, c)]);
    if (h.isNotEmpty) return h.first;
  }
  for (var c = 0; c < dims.cols; c++) {
    final h = scan([for (var r = 0; r < dims.rows; r++) GridCoordinate(r, c)]);
    if (h.isNotEmpty) return h.first;
  }
  for (var b = 0; b < box.boxCount(dims); b++) {
    final h = scan(box.coordinatesInBox(b, dims));
    if (h.isNotEmpty) return h.first;
  }
  return null;
}

double _complexity(Map<GridCoordinate, Set<int>> cands) {
  final n = dims.cols;
  final emptyCount = cands.length;
  final denom = emptyCount * (n - 2);
  if (denom <= 0) return 0;
  var sum = 0;
  for (final s in cands.values) {
    final excess = s.length - 2;
    if (excess > 0) sum += excess;
  }
  final v = sum / denom;
  return v < 0 ? 0 : (v > 1 ? 1 : v);
}

// ---- helpers --------------------------------------------------------------

int _blanks(List<List<int>> grid) {
  var n = 0;
  for (final row in grid) {
    for (final v in row) {
      if (v == 0) n++;
    }
  }
  return n;
}

double _pearson(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n == 0) return 0;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0, dx = 0.0, dy = 0.0;
  for (var i = 0; i < n; i++) {
    final a = xs[i] - mx;
    final b = ys[i] - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }
  if (dx == 0 || dy == 0) return 0;
  return num / sqrt(dx * dy);
}

double _stddev(double sum, double sqSum, int n) {
  if (n <= 0) return 0;
  final mean = sum / n;
  final variance = sqSum / n - mean * mean;
  return variance <= 0 ? 0 : sqrt(variance);
}

String _row(List<String> cols) {
  const widths = [6, 9, 9, 8, 9, 12, 9, 8, 11, 9];
  final b = StringBuffer();
  for (var i = 0; i < cols.length; i++) {
    b.write(cols[i].padRight(widths[i]));
  }
  return b.toString();
}
