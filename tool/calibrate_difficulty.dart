// Generation calibration (pure Dart — run with:
//   dart run tool/calibrate_difficulty.dart          (6×6 default board)
//   dart run tool/calibrate_difficulty.dart 9x9      (9×9 feasibility board)
//
// Optional args: samples=N (runs per label, default 10) and maxAttempts=N
// (attempt budget per run, default 60), e.g.:
//   dart run tool/calibrate_difficulty.dart 9x9 samples=5 maxAttempts=200
//
// Confirms, under the complexity-based difficulty model, that each label is
// generatable in a reasonable number of attempts and reports the resulting
// candidate_complexity + blank count. On 6×6, Deep lives at near-minimal
// puzzles and needs far more attempts than the other labels; the tool reports
// that plainly rather than hiding it.
//
// Each generated puzzle is additionally re-verified INDEPENDENTLY of the
// generator (9×9 feasibility spike — see docs/9x9_generation_feasibility_prompt.md):
// solution validity (complete, conflict-free, values in 1..runeCount), givens
// consistent with the solution, and solution uniqueness via a fresh
// FastUniquenessSolver. Per-puzzle rows also break down the human-solver
// technique usage (naked/hidden singles vs decision points). Nothing here is
// part of the app build.

import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/difficulty_scorer.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_rules.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/fast_uniqueness_solver.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/solving_technique.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

/// 9×9 feasibility board (chapter-system spike). Deliberately defined HERE and
/// not in lib/ so no shipped code path can reach it; the only 9×9 entry points
/// are the dev tools' explicit `9x9` argument.
const BoardConfig nineByNine = BoardConfig(
  dimensions: GridDimensions(rows: 9, cols: 9),
  boxShape: BoxShape(rows: 3, cols: 3),
  runeCount: 9,
);

void main(List<String> args) {
  final board = args.contains('9x9') ? nineByNine : BoardConfig.sixBySix;
  final samples = _intArg(args, 'samples=', 10);
  final maxAttempts = _intArg(args, 'maxAttempts=', 60);

  final dims = board.dimensions;
  final box = board.boxShape;
  final generator = PuzzleGenerator(board: board);
  const scorer = DifficultyScorer();
  final rules = RunicSudokuRules(
    dimensions: dims,
    boxShape: box,
    runeCount: board.runeCount,
  );

  print('Per-label generatability — complexity-based model, '
      '${dims.toToken()} (box ${box.toToken()}, ${board.runeCount} runes).');
  print('Bands: Quick<${DifficultyTuning.complexityQuickMax}  '
      'Normal<${DifficultyTuning.complexityNormalMax}  '
      'Tricky<${DifficultyTuning.complexityTrickyMax}  '
      'Deep>=${DifficultyTuning.complexityTrickyMax}');
  print('$samples runs per label, maxAttempts=$maxAttempts');
  print('');

  for (final label in DifficultyLabel.values) {
    var ok = 0;
    var attemptsSum = 0;
    var complexitySum = 0.0;
    var blankSum = 0;
    var estSum = 0;
    var genMsSum = 0;
    var genMsMax = 0;
    var uniquePass = 0;
    var validPass = 0;
    var noDecisionPoints = 0; // solved by naked/hidden singles alone
    final sw = Stopwatch();

    for (var s = 0; s < samples; s++) {
      sw.reset();
      sw.start();
      try {
        final r = generator.generate(
          target: label,
          seed: 1000 + s * 101,
          maxAttempts: maxAttempts,
        );
        sw.stop();
        final genMs = sw.elapsedMilliseconds;
        ok++;
        attemptsSum += r.attempts;
        complexitySum += r.metrics.candidateComplexity;
        blankSum += _blanks(r.level.givenCells);
        estSum += r.metrics.estimatedSolveTime.inSeconds;
        genMsSum += genMs;
        if (genMs > genMsMax) genMsMax = genMs;
        // sanity: generated label must classify back to the target
        assert(scorer.classify(r.metrics) == label);

        // ---- independent re-verification (not trusting the generator) ----
        final solutionOk = rules.isCompleteAndValid(r.level.solutionGrid) &&
            _valuesInRange(r.level.solutionGrid, board.runeCount);
        final givensOk =
            _givensConsistent(r.level.givenCells, r.level.solutionGrid);
        final solutionCount =
            FastUniquenessSolver(dimensions: dims, boxShape: box)
                .countSolutions(r.level.givenCells, maxSolutions: 2);
        final unique = solutionCount == 1;
        if (unique) uniquePass++;
        if (solutionOk && givensOk) validPass++;

        var naked = 0;
        var hidden = 0;
        var decisions = 0;
        for (final step in r.metrics.solverStepsLog) {
          if (step.technique == SolvingTechnique.nakedSingle) naked++;
          if (step.technique == SolvingTechnique.hiddenSingle) hidden++;
          if (step.technique == SolvingTechnique.decisionPoint) decisions++;
        }
        if (decisions == 0 && r.metrics.solved) noDecisionPoints++;

        print('  ${label.token.padRight(7)} #$s seed=${1000 + s * 101} '
            'attempts=${r.attempts} genMs=$genMs '
            'blanks=${_blanks(r.level.givenCells)} '
            'cx=${r.metrics.candidateComplexity.toStringAsFixed(3)} '
            'est=${r.metrics.estimatedSolveTime.inSeconds}s '
            'valid=${solutionOk && givensOk ? 'PASS' : 'FAIL'} '
            'unique=${unique ? 'PASS' : 'FAIL(count=$solutionCount)'} '
            'naked=$naked hidden=$hidden decisionPoints=$decisions '
            'solved=${r.metrics.solved}');
      } on StateError catch (e) {
        sw.stop();
        // Generation failed within maxAttempts (the only expected failure mode;
        // anything else should propagate loudly — feasibility stop condition).
        print('  ${label.token.padRight(7)} #$s FAILED after '
            '${sw.elapsedMilliseconds}ms: ${e.message.toString().split('\n').first}');
      }
    }

    if (ok == 0) {
      print('${label.token.padRight(7)} NOT generatable on ${dims.toToken()} '
          '(0/$samples) within maxAttempts=$maxAttempts');
    } else {
      print('${label.token.padRight(7)} ok=$ok/$samples  '
          'avgAttempts=${(attemptsSum / ok).toStringAsFixed(1)}  '
          'avgComplexity=${(complexitySum / ok).toStringAsFixed(3)}  '
          'avgBlanks=${(blankSum / ok).toStringAsFixed(1)}  '
          'avgEst=${(estSum / ok).toStringAsFixed(0)}s  '
          'avgGenMs=${(genMsSum / ok).toStringAsFixed(0)}  maxGenMs=$genMsMax  '
          'valid=$validPass/$ok  unique=$uniquePass/$ok  '
          'noDecisionPoints=$noDecisionPoints/$ok');
    }
    print('');
  }
}

int _intArg(List<String> args, String prefix, int fallback) {
  for (final a in args) {
    if (a.startsWith(prefix)) {
      final v = int.tryParse(a.substring(prefix.length));
      if (v != null) return v;
    }
  }
  return fallback;
}

int _blanks(List<List<int>> grid) {
  var n = 0;
  for (final row in grid) {
    for (final v in row) {
      if (v == 0) n++;
    }
  }
  return n;
}

bool _givensConsistent(List<List<int>> givens, List<List<int>> solution) {
  for (var r = 0; r < givens.length; r++) {
    for (var c = 0; c < givens[r].length; c++) {
      final v = givens[r][c];
      if (v != 0 && v != solution[r][c]) return false;
    }
  }
  return true;
}

bool _valuesInRange(List<List<int>> grid, int runeCount) {
  for (final row in grid) {
    for (final v in row) {
      if (v < 1 || v > runeCount) return false;
    }
  }
  return true;
}
