import '../../core/save/snapshot.dart';
import '../../grid/box_shape.dart';
import '../../grid/grid_dimensions.dart';

/// Complete, serializable state of a Runic Sudoku level.
///
/// Implements [Snapshot] so it can be stored by the generic save service. All
/// fields from the Phase 0 schema are present. Internally we keep structured
/// types ([GridDimensions], [BoxShape], [Duration], [DateTime]); on the wire we
/// emit the Phase 0 token forms ("6x6", "2x3"), millisecond durations and
/// ISO-8601 timestamps. See "Specification ambiguities" in PHASE1_NOTES.md.
class RunicSudokuSnapshot implements Snapshot {
  static const String gameIdValue = 'runic_sudoku';

  @override
  final String gameId;
  @override
  final String levelId;

  final int seed;
  final GridDimensions gridSize;
  final BoxShape boxShape;

  /// n×n; 0 = empty. Row-major.
  final List<List<int>> solutionGrid;

  /// Clue cells (the puzzle givens); 0 = not a given. Row-major.
  final List<List<int>> givenCells;

  /// Player's current board; 0 = empty. Row-major.
  final List<List<int>> currentGrid;

  /// Candidate marks per cell (sorted ascending). Row-major; inner list may be
  /// empty.
  final List<List<List<int>>> notesGrid;

  final int mistakesCount;
  final int hintsUsed;

  /// Number of "check mistakes" actions used this puzzle (Phase 3). The first is
  /// free; subsequent ones require a rewarded ad. NOTE: this field is NOT in the
  /// Phase 0 §6.3 schema — see PHASE3_NOTES.md "Specification ambiguities".
  final int checksUsed;

  final DateTime startedAt;
  final Duration elapsedTime;
  final DateTime lastSavedAt;

  final bool completed;

  final String difficultyLabel;
  final Duration estimatedSolveTime;

  /// Total play time once solved; null while unfinished.
  final Duration? actualSolveTime;

  const RunicSudokuSnapshot({
    this.gameId = gameIdValue,
    required this.levelId,
    required this.seed,
    required this.gridSize,
    required this.boxShape,
    required this.solutionGrid,
    required this.givenCells,
    required this.currentGrid,
    required this.notesGrid,
    required this.mistakesCount,
    required this.hintsUsed,
    this.checksUsed = 0,
    required this.startedAt,
    required this.elapsedTime,
    required this.lastSavedAt,
    required this.completed,
    required this.difficultyLabel,
    required this.estimatedSolveTime,
    this.actualSolveTime,
  });

  @override
  String get saveKey => '$gameId/$levelId';

  @override
  Map<String, dynamic> toJson() => {
        'game_id': gameId,
        'level_id': levelId,
        'seed': seed,
        'grid_size': gridSize.toToken(),
        'box_shape': boxShape.toToken(),
        'solution_grid': solutionGrid,
        'given_cells': givenCells,
        'current_grid': currentGrid,
        'notes_grid': notesGrid,
        'mistakes_count': mistakesCount,
        'hints_used': hintsUsed,
        'checks_used': checksUsed,
        'started_at': startedAt.toIso8601String(),
        'elapsed_time': elapsedTime.inMilliseconds,
        'last_saved_at': lastSavedAt.toIso8601String(),
        'completed': completed,
        'difficulty_label': difficultyLabel,
        'estimated_solve_time': estimatedSolveTime.inMilliseconds,
        'actual_solve_time': actualSolveTime?.inMilliseconds,
      };

  factory RunicSudokuSnapshot.fromJson(Map<String, dynamic> json) {
    List<List<int>> grid(dynamic raw) => [
          for (final row in (raw as List))
            [for (final v in (row as List)) (v as num).toInt()],
        ];
    List<List<List<int>>> notes(dynamic raw) => [
          for (final row in (raw as List))
            [
              for (final cell in (row as List))
                [for (final v in (cell as List)) (v as num).toInt()],
            ],
        ];

    final actual = json['actual_solve_time'];
    return RunicSudokuSnapshot(
      gameId: json['game_id'] as String? ?? gameIdValue,
      levelId: json['level_id'] as String,
      seed: (json['seed'] as num).toInt(),
      gridSize: GridDimensions.parse(json['grid_size'] as String),
      boxShape: BoxShape.parse(json['box_shape'] as String),
      solutionGrid: grid(json['solution_grid']),
      givenCells: grid(json['given_cells']),
      currentGrid: grid(json['current_grid']),
      notesGrid: notes(json['notes_grid']),
      mistakesCount: (json['mistakes_count'] as num).toInt(),
      hintsUsed: (json['hints_used'] as num).toInt(),
      checksUsed: (json['checks_used'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.parse(json['started_at'] as String),
      elapsedTime: Duration(milliseconds: (json['elapsed_time'] as num).toInt()),
      lastSavedAt: DateTime.parse(json['last_saved_at'] as String),
      completed: json['completed'] as bool,
      difficultyLabel: json['difficulty_label'] as String,
      estimatedSolveTime:
          Duration(milliseconds: (json['estimated_solve_time'] as num).toInt()),
      actualSolveTime:
          actual == null ? null : Duration(milliseconds: (actual as num).toInt()),
    );
  }

  RunicSudokuSnapshot copyWith({
    List<List<int>>? currentGrid,
    List<List<List<int>>>? notesGrid,
    int? mistakesCount,
    int? hintsUsed,
    int? checksUsed,
    Duration? elapsedTime,
    DateTime? lastSavedAt,
    bool? completed,
    Duration? actualSolveTime,
  }) {
    return RunicSudokuSnapshot(
      gameId: gameId,
      levelId: levelId,
      seed: seed,
      gridSize: gridSize,
      boxShape: boxShape,
      solutionGrid: solutionGrid,
      givenCells: givenCells,
      currentGrid: currentGrid ?? this.currentGrid,
      notesGrid: notesGrid ?? this.notesGrid,
      mistakesCount: mistakesCount ?? this.mistakesCount,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      checksUsed: checksUsed ?? this.checksUsed,
      startedAt: startedAt,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      completed: completed ?? this.completed,
      difficultyLabel: difficultyLabel,
      estimatedSolveTime: estimatedSolveTime,
      actualSolveTime: actualSolveTime ?? this.actualSolveTime,
    );
  }
}
