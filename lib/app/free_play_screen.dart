import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../games/runic_sudoku/chapter_theme.dart';
import '../games/runic_sudoku/generator/level_data.dart';
import '../games/runic_sudoku/generator/puzzle_generator.dart';
import '../games/runic_sudoku/manual_puzzle.dart';
import '../games/runic_sudoku/preparing_overlay.dart';
import '../games/runic_sudoku/runic_sudoku_snapshot.dart';
import '../games/runic_sudoku/solver/difficulty_constants.dart';
import 'app.dart';

/// Single save slot id shared by all Free Play sessions (Phase 3.66.2). Distinct
/// from any campaign (`rs_NNN`) or daily key, so Free Play never overwrites them.
const String freePlaySaveLevelId = 'active_freeplay';

/// Generation attempt budgets for on-demand Free Play. Deep needs the most
/// headroom because the Free Play guardrails reject more near-minimal puzzles.
const Map<String, int> _freePlayMaxAttempts = {
  'Quick': 200,
  'Normal': 200,
  'Tricky': 400,
  'Deep': 1200,
};

/// Runs in a background isolate (via [compute]) so generation never janks the UI
/// thread. Returns the level JSON, or null if generation failed.
Map<String, dynamic>? generateFreePlayLevelJson(String token) {
  final label = DifficultyLabel.fromToken(token);
  try {
    final result = PuzzleGenerator().generate(
      target: label,
      maxAttempts: _freePlayMaxAttempts[token] ?? 400,
      freePlay: true,
    );
    return result.level.toJson();
  } on StateError {
    return null;
  }
}

/// Generates a Free Play puzzle off the UI thread and wraps it in a
/// [ManualPuzzle]. All Free Play puzzles of one difficulty reuse a single save
/// slot id (`freeplay_<label>`); the screen loads them `fresh`, so the slot is
/// only an app-pause scratch buffer and never resumes a stale puzzle.
Future<ManualPuzzle?> generateFreePlayPuzzle(DifficultyLabel label) async {
  final json = await compute(generateFreePlayLevelJson, label.token);
  if (json == null) return null;
  final data = LevelData.fromJson(json);
  return ManualPuzzle(
    levelId: freePlaySaveLevelId,
    seed: data.seed ?? 0,
    gridSize: data.gridSize,
    boxShape: data.boxShape,
    solutionGrid: data.solutionGrid,
    givenCells: data.givenCells,
    difficultyLabel: data.difficultyLabel,
    estimatedSolveTime: data.estimatedSolveTime ?? Duration.zero,
  );
}

/// One Free Play difficulty option (icon + fixed, friendly time label).
class _FreeOption {
  final DifficultyLabel label;
  final String emoji;
  final String time;
  const _FreeOption(this.label, this.emoji, this.time);
}

const List<_FreeOption> _options = [
  _FreeOption(DifficultyLabel.quick, '⚡', '~1 min'),
  _FreeOption(DifficultyLabel.normal, '📜', '~2 min'),
  _FreeOption(DifficultyLabel.tricky, '💎', '~5 min'),
  _FreeOption(DifficultyLabel.deep, '🌑', '~7 min'),
];

/// Free Play entry: pick a difficulty, then an on-demand puzzle is generated.
class FreeDifficultySelectScreen extends StatefulWidget {
  final AppServices services;

  const FreeDifficultySelectScreen({super.key, required this.services});

  @override
  State<FreeDifficultySelectScreen> createState() =>
      _FreeDifficultySelectScreenState();
}

class _FreeDifficultySelectScreenState
    extends State<FreeDifficultySelectScreen> {
  static const Color _gold = Color(0xFFE0A94A);
  static const Color _onGold = Color(0xFF120E08);
  static const Color _light = Color(0xFFF2EAD8);

  bool _generating = false;

  /// An interrupted Free Play session that can be resumed (Phase 3.66.2).
  RunicSudokuSnapshot? _resumable;

  static String get _freePlayKey =>
      '${RunicSudokuSnapshot.gameIdValue}/$freePlaySaveLevelId';

  @override
  void initState() {
    super.initState();
    // Starting a fresh Free Play session resets the consecutive streak.
    widget.services.appController.resetFreePlayStreak();
    // Not in gameplay here: top the Deep cache back up in the background.
    widget.services.deepCache?.startRefill();
    _checkResumable();
  }

  Future<void> _checkResumable() async {
    final raw = await widget.services.save.load(_freePlayKey);
    if (!mounted || raw == null) return;
    final snap = RunicSudokuSnapshot.fromJson(raw);
    // Only offer to resume an unfinished session.
    if (!snap.completed) setState(() => _resumable = snap);
  }

  /// The "Next Trial" supplier for [label] (Deep from the cache, others on
  /// demand).
  Future<ManualPuzzle?> Function() _generateNextFor(DifficultyLabel label) =>
      label == DifficultyLabel.deep
          ? _nextDeep
          : () => generateFreePlayPuzzle(label);

  Future<void> _continueResume() async {
    final snap = _resumable;
    if (snap == null) return;
    final label = DifficultyLabel.fromToken(snap.difficultyLabel);
    final puzzle = ManualPuzzle(
      levelId: freePlaySaveLevelId,
      seed: snap.seed,
      gridSize: snap.gridSize,
      boxShape: snap.boxShape,
      solutionGrid: snap.solutionGrid,
      givenCells: snap.givenCells,
      difficultyLabel: snap.difficultyLabel,
      estimatedSolveTime: snap.estimatedSolveTime,
    );
    setState(() => _resumable = null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.services.freePlayScreen(
          puzzle,
          label,
          generateNext: _generateNextFor(label),
          resume: true,
        ),
      ),
    );
  }

  Future<void> _discardResume() async {
    final snap = _resumable;
    await widget.services.save.delete(_freePlayKey);
    if (!mounted) return;
    setState(() => _resumable = null);
    // "New Trial": immediately start a fresh puzzle of the same difficulty.
    if (snap != null) {
      await _start(DifficultyLabel.fromToken(snap.difficultyLabel));
    }
  }

  Future<void> _start(DifficultyLabel label) async {
    if (_generating) return;
    // Deep is never generated on tap — it is served instantly from the bundled
    // pool / rolling cache (Phase 3.66.1).
    if (label == DifficultyLabel.deep) {
      await _startDeep();
      return;
    }
    setState(() => _generating = true);
    final puzzle = await generateFreePlayPuzzle(label);
    if (!mounted) return;
    setState(() => _generating = false);
    if (puzzle == null) {
      await _showError(
          'Generation failed', 'Could not generate a puzzle. Please try again.');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.services.freePlayScreen(
          puzzle,
          label,
          generateNext: () => generateFreePlayPuzzle(label),
        ),
      ),
    );
  }

  Future<void> _startDeep() async {
    final cache = widget.services.deepCache;
    ManualPuzzle? puzzle;
    if (cache != null) {
      // Reading cache/pool is instant; only show the overlay if it somehow
      // exceeds 200ms.
      final entry = await _withDelayedOverlay(cache.nextPuzzle);
      puzzle = entry?.toManualPuzzle();
    } else {
      // No cache wired (e.g. tests): fall back to on-demand generation.
      setState(() => _generating = true);
      puzzle = await generateFreePlayPuzzle(DifficultyLabel.deep);
      if (mounted) setState(() => _generating = false);
    }
    if (!mounted) return;
    final p = puzzle;
    if (p == null) {
      await _showError('Deep Trials',
          'Deep Trials are being prepared.\nTry another difficulty and return shortly.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.services.freePlayScreen(
          p,
          DifficultyLabel.deep,
          generateNext: _nextDeep,
        ),
      ),
    );
  }

  /// "Next Trial" supplier for Deep: pull the next cached/bundled puzzle.
  Future<ManualPuzzle?> _nextDeep() async {
    final cache = widget.services.deepCache;
    if (cache == null) return generateFreePlayPuzzle(DifficultyLabel.deep);
    final entry = await cache.nextPuzzle();
    return entry?.toManualPuzzle();
  }

  /// Runs [op], showing the loading overlay only if it takes longer than 200ms.
  Future<T> _withDelayedOverlay<T>(Future<T> Function() op) async {
    final timer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _generating = true);
    });
    try {
      return await op();
    } finally {
      timer.cancel();
      if (mounted && _generating) setState(() => _generating = false);
    }
  }

  Future<void> _showError(String title, String message) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Free Play')),
          body: ChapterBackground(
            assetPath: ChapterBackgrounds.neutral,
            overlayOpacity: 0.6,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_resumable != null) ...[
                      _ResumeBanner(
                        snapshot: _resumable!,
                        gold: _gold,
                        light: _light,
                        onContinue: _continueResume,
                        onNewTrial: _discardResume,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Choose your difficulty',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _light,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final o in _options) ...[
                      _DifficultyButton(
                        option: o,
                        gold: _gold,
                        onGold: _onGold,
                        onPressed: _generating ? null : () => _start(o.label),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_generating) const PreparingOverlay(),
      ],
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final _FreeOption option;
  final Color gold;
  final Color onGold;
  final VoidCallback? onPressed;

  const _DifficultyButton({
    required this.option,
    required this.gold,
    required this.onGold,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: onGold,
          minimumSize: const Size(260, 54),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(option.label.token),
            const Spacer(),
            Text(
              option.time,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: onGold.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offers to resume an interrupted Free Play session (Phase 3.66.2).
class _ResumeBanner extends StatelessWidget {
  final RunicSudokuSnapshot snapshot;
  final Color gold;
  final Color light;
  final VoidCallback onContinue;
  final VoidCallback onNewTrial;

  const _ResumeBanner({
    required this.snapshot,
    required this.gold,
    required this.light,
    required this.onContinue,
    required this.onNewTrial,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            'Continue your ${snapshot.difficultyLabel} trial?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: light, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(snapshot.elapsedTime)} elapsed',
            style: TextStyle(color: light.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: onNewTrial,
                child: Text('New Trial', style: TextStyle(color: light)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF120E08),
                ),
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
