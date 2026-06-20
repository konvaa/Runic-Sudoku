import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/games/runic_sudoku/chapter_theme.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

ManualPuzzle _lvl(String id, String label) => ManualPuzzle(
      levelId: id,
      seed: 0,
      gridSize: const GridDimensions(rows: 1, cols: 1),
      boxShape: const BoxShape(rows: 1, cols: 1),
      solutionGrid: const [
        [1]
      ],
      givenCells: const [
        [0]
      ],
      difficultyLabel: label,
      estimatedSolveTime: const Duration(minutes: 1),
    );

void main() {
  test('each difficulty label maps to its chapter background', () {
    expect(ChapterBackgrounds.forLabel('Quick'),
        'assets/backgrounds/quick_runes_bg.png');
    expect(ChapterBackgrounds.forLabel('Normal'),
        'assets/backgrounds/normal_seals_bg.png');
    expect(ChapterBackgrounds.forLabel('Tricky'),
        'assets/backgrounds/tricky_glyphs_bg.png');
    expect(ChapterBackgrounds.forLabel('Deep'),
        'assets/backgrounds/deep_chambers_bg.png');
  });

  test('unknown / null label falls back to the neutral background', () {
    expect(ChapterBackgrounds.forLabel(null), ChapterBackgrounds.neutral);
    expect(ChapterBackgrounds.forLabel('Nope'), ChapterBackgrounds.neutral);
    expect(ChapterBackgrounds.neutral, 'assets/backgrounds/default_rune_bg.png');
  });

  test('forLevel resolves a level to its chapter background', () {
    final pool = LevelPool([
      _lvl('q0', 'Quick'),
      _lvl('n0', 'Normal'),
      _lvl('d0', 'Deep'),
    ]);
    final progression = Progression.fromPool(pool);
    expect(ChapterBackgrounds.forLevel(progression, 'q0'),
        'assets/backgrounds/quick_runes_bg.png');
    expect(ChapterBackgrounds.forLevel(progression, 'd0'),
        'assets/backgrounds/deep_chambers_bg.png');
    // A level not in the campaign -> neutral.
    expect(ChapterBackgrounds.forLevel(progression, 'rs_unknown'),
        ChapterBackgrounds.neutral);
  });

  test('allAssets lists the five backgrounds', () {
    expect(ChapterBackgrounds.allAssets.length, 5);
    expect(ChapterBackgrounds.allAssets, contains(ChapterBackgrounds.neutral));
  });
}
