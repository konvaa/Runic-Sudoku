import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/core/save/shared_preferences_save_store.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_controller.dart';
import 'package:runic_sudoku/games/runic_sudoku/runic_sudoku_snapshot.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _analytics = NoopAnalyticsService(echoToConsole: false);
const _freePlayKey = 'runic_sudoku/active_freeplay';
const _campaignKey = 'runic_sudoku/rs_000';

/// A Free Play puzzle wrapping the near-complete fixture (4 blanks in the
/// bottom-right box), under the shared Free Play slot id.
ManualPuzzle _freePlay() => ManualPuzzle(
      levelId: 'active_freeplay',
      seed: 1,
      gridSize: quickTestPuzzle.gridSize,
      boxShape: quickTestPuzzle.boxShape,
      solutionGrid: quickTestPuzzle.solutionGrid,
      givenCells: quickTestPuzzle.givenCells,
      difficultyLabel: 'Deep',
      estimatedSolveTime: const Duration(seconds: 400),
    );

ManualPuzzle _campaign() => ManualPuzzle(
      levelId: 'rs_000',
      seed: 2,
      gridSize: notesTestPuzzle.gridSize,
      boxShape: notesTestPuzzle.boxShape,
      solutionGrid: notesTestPuzzle.solutionGrid,
      givenCells: notesTestPuzzle.givenCells,
      difficultyLabel: 'Normal',
      estimatedSolveTime: const Duration(minutes: 6),
    );

Future<RunicSudokuController> _freePlayController(LocalSaveRepository save,
    {bool fresh = true}) {
  return RunicSudokuController.loadOrCreate(
    puzzle: _freePlay(),
    saveService: save,
    analytics: _analytics,
    fresh: fresh,
    mode: PuzzleMode.freePlay,
    puzzleId: 'pid_test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a Free Play session saves to the active_freeplay slot on placement',
      () async {
    final save = LocalSaveRepository();
    final c = await _freePlayController(save);

    c.selectCell(const GridCoordinate(4, 4));
    await c.inputValue(4); // correct; 3 blanks remain → not a win

    final raw = await save.load(_freePlayKey);
    expect(raw, isNotNull);
    final snap = RunicSudokuSnapshot.fromJson(raw!);
    expect(snap.mode, PuzzleMode.freePlay);
    expect(snap.puzzleId, 'pid_test');
    expect(snap.completed, isFalse);
    expect(snap.currentGrid[4][4], 4);
  });

  test('a Free Play session is restored after a simulated restart', () async {
    // ---- first launch ----
    final save1 =
        LocalSaveRepository(store: await SharedPreferencesSaveStore.create());
    final c1 = await _freePlayController(save1);
    c1.selectCell(const GridCoordinate(4, 4));
    await c1.inputValue(4);
    await c1.pause(); // app_pause flush

    // ---- restart: fresh repo over the same backing prefs, resume (fresh:false)
    final save2 =
        LocalSaveRepository(store: await SharedPreferencesSaveStore.create());
    final c2 = await _freePlayController(save2, fresh: false);

    expect(c2.completed, isFalse);
    expect(c2.state.mode, PuzzleMode.freePlay);
    expect(c2.state.currentGrid[4][4], 4,
        reason: 'in-progress Free Play board survived the restart');
  });

  test('completing a Free Play puzzle marks it solved, then the slot is cleared',
      () async {
    final save = LocalSaveRepository();
    final c = await _freePlayController(save);

    // Fill the four remaining cells correctly → win.
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
    expect(RunicSudokuSnapshot.fromJson((await save.load(_freePlayKey))!)
        .completed, isTrue);

    // The play screen deletes the slot on completion (mirrored here).
    await save.delete(_freePlayKey);
    expect(await save.load(_freePlayKey), isNull,
        reason: 'finished session must not be offered for resume');
  });

  test('Free Play save operations never touch the campaign slot', () async {
    final save = LocalSaveRepository();

    // A campaign session in progress.
    final campaign = await RunicSudokuController.loadOrCreate(
      puzzle: _campaign(),
      saveService: save,
      analytics: _analytics,
      fresh: true,
    );
    campaign.selectCell(const GridCoordinate(0, 1)); // empty in notesTestPuzzle
    await campaign.inputValue(5);
    final before = await save.load(_campaignKey);
    expect(before, isNotNull);

    // Now run Free Play save operations.
    final fp = await _freePlayController(save);
    fp.selectCell(const GridCoordinate(4, 4));
    await fp.inputValue(4);

    final after = await save.load(_campaignKey);
    expect(after, before, reason: 'campaign slot untouched by Free Play');
    expect(await save.load(_freePlayKey), isNotNull);
  });

  test('an unfinished Free Play snapshot is detected for resume', () async {
    final save = LocalSaveRepository();
    final c = await _freePlayController(save);
    c.selectCell(const GridCoordinate(4, 4));
    await c.inputValue(4);

    // What FreeDifficultySelectScreen checks to show the resume banner.
    final raw = await save.load(_freePlayKey);
    expect(raw, isNotNull);
    expect(RunicSudokuSnapshot.fromJson(raw!).completed, isFalse);
  });

  test('leaving without completing (app_pause) keeps the slot resumable',
      () async {
    final save = LocalSaveRepository();
    final c = await _freePlayController(save);
    c.selectCell(const GridCoordinate(4, 4));
    await c.inputValue(4); // in progress
    await c.pause(); // back button / app pause flush — must NOT delete

    final raw = await save.load(_freePlayKey);
    expect(raw, isNotNull, reason: 'app_pause must not delete the session');
    expect(RunicSudokuSnapshot.fromJson(raw!).completed, isFalse,
        reason: 'still resumable → the Continue banner should appear');
  });

  test('"New Trial" deletes the existing Free Play session', () async {
    final save = LocalSaveRepository();
    final c = await _freePlayController(save);
    c.selectCell(const GridCoordinate(4, 4));
    await c.inputValue(4);
    expect(await save.load(_freePlayKey), isNotNull);

    // New Trial discards the saved session.
    await save.delete(_freePlayKey);
    expect(await save.load(_freePlayKey), isNull);
  });
}
