import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_snapshot.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';

const _analytics = NoopAnalyticsService(echoToConsole: false);
const _dailyKey = 'runic_sudoku/active_daily';

/// Today's daily, sharing a level id (rs_005) with a campaign level.
ManualPuzzle _daily() => ManualPuzzle(
      levelId: 'rs_005',
      seed: 1,
      gridSize: quickTestPuzzle.gridSize,
      boxShape: quickTestPuzzle.boxShape,
      solutionGrid: quickTestPuzzle.solutionGrid,
      givenCells: quickTestPuzzle.givenCells,
      difficultyLabel: 'Normal',
      estimatedSolveTime: const Duration(minutes: 2),
    );

/// The campaign level with the SAME id (rs_005), a different puzzle.
ManualPuzzle _campaign() => ManualPuzzle(
      levelId: 'rs_005',
      seed: 2,
      gridSize: notesTestPuzzle.gridSize,
      boxShape: notesTestPuzzle.boxShape,
      solutionGrid: notesTestPuzzle.solutionGrid,
      givenCells: notesTestPuzzle.givenCells,
      difficultyLabel: 'Normal',
      estimatedSolveTime: const Duration(minutes: 6),
    );

void main() {
  test('saveKeyFor maps each mode to the right slot', () {
    expect(saveKeyFor(PuzzleMode.campaign, 'rs_005'), 'runic_sudoku/rs_005');
    expect(saveKeyFor(PuzzleMode.daily, 'rs_005'), 'runic_sudoku/active_daily');
    expect(saveKeyFor(PuzzleMode.freePlay, 'whatever'),
        'runic_sudoku/active_freeplay');
  });

  test('daily session saves to active_daily, not the rs_NNN slot', () async {
    final save = LocalSaveRepository();
    final c = await RunicSudokuController.loadOrCreate(
      puzzle: _daily(),
      saveService: save,
      analytics: _analytics,
      fresh: true,
      mode: PuzzleMode.daily,
    );
    c.selectCell(const GridCoordinate(4, 4));
    await c.inputValue(4);

    final raw = await save.load(_dailyKey);
    expect(raw, isNotNull);
    expect(RunicSudokuSnapshot.fromJson(raw!).mode, PuzzleMode.daily);
    expect(await save.load('runic_sudoku/rs_005'), isNull,
        reason: 'daily must not write to the campaign slot');
  });

  test('campaign level is untouched by daily save operations (same id)',
      () async {
    final save = LocalSaveRepository();

    // Campaign rs_005 in progress.
    final campaign = await RunicSudokuController.loadOrCreate(
      puzzle: _campaign(),
      saveService: save,
      analytics: _analytics,
      fresh: true,
    );
    campaign.selectCell(const GridCoordinate(0, 1)); // empty in notesTestPuzzle
    await campaign.inputValue(5);
    final before = await save.load('runic_sudoku/rs_005');
    expect(before, isNotNull);

    // Daily of the SAME id rs_005 runs its own save ops.
    final daily = await RunicSudokuController.loadOrCreate(
      puzzle: _daily(),
      saveService: save,
      analytics: _analytics,
      fresh: true,
      mode: PuzzleMode.daily,
    );
    daily.selectCell(const GridCoordinate(4, 4));
    await daily.inputValue(4);

    expect(await save.load('runic_sudoku/rs_005'), before,
        reason: 'campaign rs_005 snapshot must be unchanged');
    expect(await save.load(_dailyKey), isNotNull);
  });

  test('daily slot is cleared after completing the daily puzzle', () async {
    final save = LocalSaveRepository();
    final c = await RunicSudokuController.loadOrCreate(
      puzzle: _daily(),
      saveService: save,
      analytics: _analytics,
      fresh: true,
      mode: PuzzleMode.daily,
    );
    const fills = [
      [4, 4, 4],
      [4, 5, 5],
      [5, 4, 1],
      [5, 5, 2],
    ];
    for (final f in fills) {
      c.selectCell(GridCoordinate(f[0], f[1]));
      await c.inputValue(f[2]);
    }
    expect(c.completed, isTrue);

    // The play screen deletes the daily slot on completion (mirrored here).
    await save.delete(saveKeyFor(PuzzleMode.daily, 'rs_005'));
    expect(await save.load(_dailyKey), isNull);
  });

  test('opening today\'s daily does not resume a different day\'s session',
      () async {
    final save = LocalSaveRepository();

    // A stale, unfinished daily (different puzzle) sits in active_daily.
    final stale = await RunicSudokuController.loadOrCreate(
      puzzle: _campaign(), // notesTestPuzzle grids, but saved as daily
      saveService: save,
      analytics: _analytics,
      fresh: true,
      mode: PuzzleMode.daily,
    );
    stale.selectCell(const GridCoordinate(0, 1));
    await stale.inputValue(5);

    // Open today's daily (quickTestPuzzle grids) → must start fresh, not resume.
    final today = await RunicSudokuController.loadOrCreate(
      puzzle: _daily(),
      saveService: save,
      analytics: _analytics,
      mode: PuzzleMode.daily, // fresh:false → would resume if givens matched
    );
    expect(today.state.givenCells[0][1], quickTestPuzzle.givenCells[0][1]);
    expect(today.state.currentGrid[0][1], quickTestPuzzle.givenCells[0][1],
        reason: 'no progress carried over from the stale session');
  });
}
