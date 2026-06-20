import '../../../grid/box_shape.dart';
import '../../../grid/grid_dimensions.dart';

/// Canonical, portable representation of a generated level.
///
/// Per Phase 0/Phase 1, the CANONICAL data is `solutionGrid` + `givenCells`;
/// [seed] is debug/supplementary only and is NOT the source of truth for
/// reproduction. Import reconstructs a level purely from the stored grids.
class LevelData {
  final GridDimensions gridSize;
  final BoxShape boxShape;
  final List<List<int>> solutionGrid;
  final List<List<int>> givenCells;
  final String difficultyLabel;

  /// Pre-computed difficulty estimate (display/sorting). Optional so hand-authored
  /// or legacy level data without it still parses.
  final Duration? estimatedSolveTime;

  /// Optional debug breadcrumb only; never required to rebuild the level.
  final int? seed;

  const LevelData({
    required this.gridSize,
    required this.boxShape,
    required this.solutionGrid,
    required this.givenCells,
    required this.difficultyLabel,
    this.estimatedSolveTime,
    this.seed,
  });

  Map<String, dynamic> toJson() => {
        'grid_size': gridSize.toToken(),
        'box_shape': boxShape.toToken(),
        'solution_grid': solutionGrid,
        'given_cells': givenCells,
        'difficulty_label': difficultyLabel,
        if (estimatedSolveTime != null)
          'estimated_solve_time': estimatedSolveTime!.inMilliseconds,
        if (seed != null) 'seed': seed,
      };

  factory LevelData.fromJson(Map<String, dynamic> json) {
    List<List<int>> grid(dynamic raw) => [
          for (final row in (raw as List))
            [for (final v in (row as List)) (v as num).toInt()],
        ];
    final est = json['estimated_solve_time'];
    return LevelData(
      gridSize: GridDimensions.parse(json['grid_size'] as String),
      boxShape: BoxShape.parse(json['box_shape'] as String),
      solutionGrid: grid(json['solution_grid']),
      givenCells: grid(json['given_cells']),
      difficultyLabel: json['difficulty_label'] as String,
      estimatedSolveTime:
          est == null ? null : Duration(milliseconds: (est as num).toInt()),
      seed: (json['seed'] as num?)?.toInt(),
    );
  }
}
