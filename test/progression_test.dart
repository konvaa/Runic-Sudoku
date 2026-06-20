import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/core/analytics/noop_analytics_service.dart';
import 'package:runic_sudoku/core/profile/app_controller.dart';
import 'package:runic_sudoku/core/save/local_save_repository.dart';
import 'package:runic_sudoku/games/runic_sudoku/level_pool.dart';
import 'package:runic_sudoku/games/runic_sudoku/manual_puzzle.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression.dart';
import 'package:runic_sudoku/games/runic_sudoku/progression_controller.dart';
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
  // 3 Quick, 3 Normal, 2 Tricky. chapterUnlockFraction 0.5 ->
  // Chapter 1 (size 3) threshold = ceil(1.5) = 2.
  LevelPool pool() => LevelPool([
        _lvl('q0', 'Quick'), _lvl('q1', 'Quick'), _lvl('q2', 'Quick'),
        _lvl('n0', 'Normal'), _lvl('n1', 'Normal'), _lvl('n2', 'Normal'),
        _lvl('t0', 'Tricky'), _lvl('t1', 'Tricky'),
      ]);
  Progression prog() =>
      Progression.fromPool(pool(), chapterUnlockFraction: 0.5);

  test('chapters built per difficulty label in order', () {
    final p = prog();
    expect(p.chapters.map((c) => c.difficultyLabel).toList(),
        ['Quick', 'Normal', 'Tricky']);
    expect(p.chapters[0].id, 'chapter_1');
    expect(p.chapters[0].levelIds, ['q0', 'q1', 'q2']);
    expect(p.levelsById['q0']!.lockedByDefault, isFalse);
    expect(p.levelsById['q1']!.lockedByDefault, isTrue);
  });

  test('new install: only the first level is unlocked', () {
    final p = prog();
    const none = <String>{};
    expect(p.isChapterUnlocked('chapter_1', none), isTrue);
    expect(p.isChapterUnlocked('chapter_2', none), isFalse);
    expect(p.isLevelUnlocked('q0', none), isTrue);
    expect(p.isLevelUnlocked('q1', none), isFalse);
    expect(p.isLevelUnlocked('n0', none), isFalse);
    expect(p.computeUnlockedLevels(none), {'q0'});
    expect(p.computeUnlockedChapters(none), {'chapter_1'});
    expect(p.nextLevelId(none), 'q0');
  });

  test('completing a level unlocks the next in the chapter', () {
    final p = prog();
    expect(p.isLevelUnlocked('q1', {'q0'}), isTrue);
    expect(p.isLevelUnlocked('q2', {'q0'}), isFalse);
    expect(p.nextLevelId({'q0'}), 'q1');
  });

  test('completing enough of a chapter unlocks the next chapter', () {
    final p = prog();
    // threshold for chapter 1 is 2.
    expect(p.isChapterUnlocked('chapter_2', {'q0'}), isFalse);
    expect(p.isChapterUnlocked('chapter_2', {'q0', 'q1'}), isTrue);
    expect(p.isLevelUnlocked('n0', {'q0', 'q1'}), isTrue);
    expect(p.isLevelUnlocked('n1', {'q0', 'q1'}), isFalse);
    // ...but unfinished earlier-chapter levels are still "next".
    expect(p.nextLevelId({'q0', 'q1'}), 'q2');
  });

  test('completed levels remain unlocked (replayable)', () {
    final p = prog();
    final completed = {'q0', 'q1', 'q2'};
    for (final id in completed) {
      expect(p.isLevelUnlocked(id, completed), isTrue);
    }
    // chapter 2 now reachable; next is its first level.
    expect(p.nextLevelId(completed), 'n0');
  });

  test('a level in a still-locked chapter is not unlocked', () {
    final p = prog();
    // chapter 3 needs 2 completed in chapter 2 (size 3 -> ceil(1.5)=2).
    expect(p.isChapterUnlocked('chapter_3', {'q0', 'q1', 'q2'}), isFalse);
    expect(p.isLevelUnlocked('t0', {'q0', 'q1', 'q2'}), isFalse);
    expect(
        p.isChapterUnlocked('chapter_3', {'q0', 'q1', 'n0', 'n1'}), isTrue);
  });

  test('chapter progress counts completed levels per chapter', () {
    final p = prog();
    expect(p.chapterProgress({'q0', 'q1', 'n0'}),
        {'chapter_1': 2, 'chapter_2': 1, 'chapter_3': 0});
  });

  group('Phase 3.5 bug fixes', () {
    Future<ProgressionController> controller() async {
      final app = await AppController.load(
        saveService: LocalSaveRepository(),
        analytics: const NoopAnalyticsService(echoToConsole: false),
      );
      final pc = ProgressionController(app: app, progression: prog());
      await pc.ensureInitialized();
      return pc;
    }

    test('bug 1: daily completion does not feed campaign progression', () async {
      final pc = await controller();
      await pc.recordCompletion('q0',
          isDaily: true, date: DateTime(2026, 6, 1));
      await pc.recordCompletion('q1',
          isDaily: true, date: DateTime(2026, 6, 2));

      expect(pc.app.completedLevelIds, isEmpty,
          reason: 'daily must not add to completed_level_ids');
      expect(pc.isCompleted('q0'), isFalse);
      expect(pc.isChapterUnlocked('chapter_2'), isFalse,
          reason: 'daily must not unlock campaign chapters');
      expect(pc.isLevelUnlocked('q1'), isFalse);
      expect(pc.app.dailyStreak, 2, reason: 'daily streak still advances');
    });

    test('bug 2: enough campaign completions unlock the next chapter in-run',
        () async {
      final pc = await controller();
      expect(pc.isChapterUnlocked('chapter_2'), isFalse);

      await pc.recordCompletion('q0'); // campaign
      await pc.recordCompletion('q1'); // chapter-1 threshold (2) reached

      // Same controller instance — no restart.
      expect(pc.isCompleted('q0'), isTrue);
      expect(pc.isChapterUnlocked('chapter_2'), isTrue);
      expect(pc.isLevelUnlocked('n0'), isTrue);
    });
  });
}
