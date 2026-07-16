// Generation calibration (pure Dart — run with:
//   dart run tool/calibrate_difficulty.dart
//
// Confirms, under the complexity-based difficulty model, that each label is
// generatable in a reasonable number of attempts and reports the resulting
// candidate_complexity + blank count. Deep is expected to be unreachable on 6×6
// (reserved for larger grids); the tool reports that plainly rather than hiding
// it. Nothing here is part of the app build.

import 'package:runic_sudoku/games/runic_sudoku/board_config.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/difficulty_scorer.dart';
import 'package:runic_sudoku/games/runic_sudoku/generator/puzzle_generator.dart';
import 'package:runic_sudoku/games/runic_sudoku/solver/difficulty_constants.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

const dims = GridDimensions(rows: 6, cols: 6);
const box = BoxShape(rows: 2, cols: 3);
const samples = 10;
const maxAttempts = 60;

void main() {
  final generator = PuzzleGenerator(board: BoardConfig.sixBySix);
  const scorer = DifficultyScorer();

  print('Per-label generatability — complexity-based model, ${dims.toToken()}.');
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

    for (var s = 0; s < samples; s++) {
      try {
        final r = generator.generate(
          target: label,
          seed: 1000 + s * 101,
          maxAttempts: maxAttempts,
        );
        ok++;
        attemptsSum += r.attempts;
        complexitySum += r.metrics.candidateComplexity;
        blankSum += _blanks(r.level.givenCells);
        estSum += r.metrics.estimatedSolveTime.inSeconds;
        // sanity: generated label must classify back to the target
        assert(scorer.classify(r.metrics) == label);
      } catch (_) {
        // generation failed within maxAttempts
      }
    }

    if (ok == 0) {
      print('${label.token.padRight(7)} NOT generatable on ${dims.toToken()} '
          '(0/$samples) — reserved for larger grids');
    } else {
      print('${label.token.padRight(7)} ok=$ok/$samples  '
          'avgAttempts=${(attemptsSum / ok).toStringAsFixed(1)}  '
          'avgComplexity=${(complexitySum / ok).toStringAsFixed(3)}  '
          'avgBlanks=${(blankSum / ok).toStringAsFixed(1)}  '
          'avgEst=${(estSum / ok).toStringAsFixed(0)}s');
    }
  }
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
