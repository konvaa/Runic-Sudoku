import 'package:flutter/material.dart' hide BoxShape;

import '../../core/ads/ads_service.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/profile/app_controller.dart';
import '../../core/purchases/purchase_service.dart';
import '../../core/save/save_service.dart';
import '../../core/theme/rune_set.dart';
import '../../grid/grid_board_widget.dart';
import '../../grid/grid_cell.dart';
import '../../grid/grid_coordinate.dart';
import 'chapter_theme.dart';
import 'freeplay/deep_free_play_cache.dart';
import 'manual_puzzle.dart';
import 'notes_panel.dart';
import 'preparing_overlay.dart';
import 'progression_controller.dart';
import 'runic_sudoku_controller.dart';
import 'runic_sudoku_snapshot.dart';
import 'runic_sudoku_symbol_validation.dart';
import 'rune_input_panel.dart';
import 'solver/difficulty_constants.dart';

/// What the player chose on the win dialog.
enum _WinAction { next, cont }

/// The Runic Sudoku play screen. Owns the controller lifecycle, wires the board
/// + input panels, persists on app pause, and (Phase 3) drives the rewarded
/// hint/check flows and the level-complete interstitial + remove-ads offer.
class RunicSudokuScreen extends StatefulWidget {
  final ManualPuzzle puzzle;
  final SaveService saveService;
  final AnalyticsService analytics;
  final SymbolSet symbolSet;
  final AdsService ads;
  final PurchaseService purchases;
  final AppController appController;
  final ProgressionController progressionController;

  /// True when this is today's daily puzzle (drives streak + win UI).
  final bool isDaily;

  /// True when launched from Free Play (Phase 3.66): on-demand puzzle, "Next
  /// Trial" loop, Free Play stats instead of campaign progression.
  final bool isFreePlay;

  /// The Free Play difficulty (required when [isFreePlay]); selects the
  /// background and is recorded with the completion.
  final DifficultyLabel? freePlayLabel;

  /// Generates the next Free Play puzzle of the same difficulty (off-thread).
  /// Returns null if generation failed. Only set for Free Play.
  final Future<ManualPuzzle?> Function()? generateNext;

  /// Deep Free Play cache (Phase 3.66.1). Used only to pause/resume background
  /// refilling around active gameplay; null in tests.
  final DeepFreePlayCache? deepCache;

  /// True when resuming a saved Free Play session (Phase 3.66.2): the first load
  /// reads the persisted snapshot instead of starting fresh.
  final bool freePlayResume;

  const RunicSudokuScreen({
    super.key,
    required this.puzzle,
    required this.saveService,
    required this.analytics,
    required this.symbolSet,
    required this.ads,
    required this.purchases,
    required this.appController,
    required this.progressionController,
    this.isDaily = false,
    this.isFreePlay = false,
    this.freePlayLabel,
    this.generateNext,
    this.deepCache,
    this.freePlayResume = false,
  });

  @override
  State<RunicSudokuScreen> createState() => _RunicSudokuScreenState();
}

class _RunicSudokuScreenState extends State<RunicSudokuScreen>
    with WidgetsBindingObserver {
  RunicSudokuController? _controller;
  bool _winShown = false;

  /// The puzzle currently being played. Equals `widget.puzzle` for campaign /
  /// daily; for Free Play it is swapped in place on "Next Trial".
  late ManualPuzzle _activePuzzle;

  /// True while a Free Play "Next Trial" puzzle is being generated.
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activePuzzle = widget.puzzle;
    // A puzzle is now active: never refill the Deep cache during gameplay.
    widget.deepCache?.stopRefill();
    _load(resume: widget.freePlayResume);
  }

  Future<void> _load({bool resume = false}) async {
    final mode = widget.isFreePlay
        ? PuzzleMode.freePlay
        : (widget.isDaily ? PuzzleMode.daily : PuzzleMode.campaign);
    final controller = await RunicSudokuController.loadOrCreate(
      puzzle: _activePuzzle,
      saveService: widget.saveService,
      analytics: widget.analytics,
      // Free Play starts fresh UNLESS we are resuming a saved session.
      fresh: widget.isFreePlay && !resume,
      mode: mode,
      puzzleId: (widget.isFreePlay || widget.isDaily)
          ? puzzleIdFromGivens(_activePuzzle.givenCells)
          : null,
    );
    // Runic Sudoku-specific guard: ensure the active set has enough symbols.
    controller.rules.requireSymbolCount(widget.symbolSet);
    if (!mounted) return;
    setState(() => _controller = controller);
    controller.resume();
    controller.addListener(_onControllerChanged);
    // Remember the most recently opened level (campaign "continue"). Free Play
    // puzzles are ephemeral and must not pollute the campaign continue slot.
    if (!widget.isFreePlay) {
      await widget.progressionController.markOpened(_activePuzzle.levelId);
    }
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c != null && c.completed && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleWin());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      c.pause(); // persists snapshot with app_pause trigger
      widget.deepCache?.stopRefill(); // never refill in background
    } else if (state == AppLifecycleState.resumed) {
      c.resume();
      // Still in a puzzle on resume → keep the cache paused.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    _controller?.pause();
    _controller?.dispose();
    // Left the puzzle: it is safe to refill the Deep cache again.
    widget.deepCache?.startRefill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Free Play picks the background from the chosen difficulty (its puzzles are
    // not in the campaign), campaign/daily resolve it via the level's chapter.
    final background = widget.isFreePlay
        ? ChapterBackgrounds.forLabel(widget.freePlayLabel!.token)
        : ChapterBackgrounds.forLevel(
            widget.progressionController.progression,
            _activePuzzle.levelId,
          );
    final title = widget.isFreePlay
        ? 'Free Play · ${_activePuzzle.difficultyLabel}'
        : _activePuzzle.difficultyLabel;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ChapterBackground(
            assetPath: background,
            overlayOpacity: 0.5,
            child: controller == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => _buildBody(context, controller),
                    ),
                  ),
          ),
        ),
        if (_generating) const PreparingOverlay(),
      ],
    );
  }

  Widget _buildBody(BuildContext context, RunicSudokuController c) {
    final scheme = Theme.of(context).colorScheme;
    final liveConflicts = c.rules.conflicts(c.state.currentGrid);
    final cells = _buildCells(c, liveConflicts);

    final style = GridBoardStyle(
      background: scheme.surface,
      cellBorder: scheme.outlineVariant,
      boxBorder: scheme.onSurface,
      givenText: scheme.onSurface,
      valueText: scheme.primary,
      noteText: scheme.onSurfaceVariant,
      errorText: scheme.error,
      selectedFill: scheme.primary.withValues(alpha: 0.18),
      highlightFill: scheme.onSurface.withValues(alpha: 0.06),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PuzzleHud(controller: c),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: GridBoardWidget(
                dimensions: c.state.dimensions,
                boxShape: c.state.boxShape,
                cells: cells,
                style: style,
                onCellTap: c.selectCell,
              ),
            ),
          ),
          const SizedBox(height: 12),
          NotesPanel(
            notesMode: c.notesMode,
            checkIsFree: c.hasFreeCheck,
            onToggleNotes: c.toggleNotesMode,
            onCheck: () => _onCheck(c),
            onHint: () => _onHint(c),
          ),
          const SizedBox(height: 12),
          RuneInputPanel(
            symbolSet: widget.symbolSet,
            count: c.rules.maxValue,
            onValue: c.inputValue,
            onErase: c.erase,
            // Hide Reset once solved (no resetting a finished puzzle).
            onReset: c.completed ? null : () => _onReset(c),
          ),
        ],
      ),
    );
  }

  List<GridCell> _buildCells(
    RunicSudokuController c,
    Set<GridCoordinate> liveConflicts,
  ) {
    final state = c.state;
    final selected = state.selected;
    final selectedValue =
        selected == null ? 0 : state.currentGrid[selected.row][selected.col];

    return [
      for (final coord in state.dimensions.coordinates)
        () {
          final value = state.currentGrid[coord.row][coord.col];
          final isSelected = coord == selected;
          final highlighted = selected != null &&
              !isSelected &&
              (_sharesUnit(c, coord, selected) ||
                  (selectedValue != 0 && value == selectedValue));
          final hasError =
              c.errorCells.contains(coord) || liveConflicts.contains(coord);
          return GridCell(
            coordinate: coord,
            primaryText:
                value == 0 ? null : widget.symbolSet.forValue(value).glyph,
            noteMarks: value != 0
                ? const []
                : (state.notesAt(coord).toList()..sort())
                    .map((v) => widget.symbolSet.forValue(v).glyph)
                    .toList(),
            isGiven: state.isGiven(coord),
            isSelected: isSelected,
            isHighlighted: highlighted,
            hasError: hasError,
          );
        }(),
    ];
  }

  bool _sharesUnit(
    RunicSudokuController c,
    GridCoordinate a,
    GridCoordinate b,
  ) {
    if (a.row == b.row || a.col == b.col) return true;
    final shape = c.state.boxShape;
    final dims = c.state.dimensions;
    return shape.boxIndexFor(a, dims) == shape.boxIndexFor(b, dims);
  }

  // ---- Rewarded hint / check (Phase 3) ------------------------------------

  Future<void> _onHint(RunicSudokuController c) async {
    if (c.completed) return;
    final result = await widget.ads.showRewardedAd(placement: 'hint');
    if (!mounted) return;
    if (result.rewardGranted) {
      await widget.appController.markRewardedShown();
      final revealed = await c.revealNextHint();
      if (revealed == null) _snack('Nothing left to hint.');
    } else {
      _snack('Ad not completed — no hint revealed.');
    }
  }

  Future<void> _onCheck(RunicSudokuController c) async {
    // First check per puzzle is free; subsequent ones need a rewarded ad.
    if (c.hasFreeCheck) {
      await c.checkMistakes();
      return;
    }
    final result = await widget.ads.showRewardedAd(placement: 'mistake_check');
    if (!mounted) return;
    if (result.rewardGranted) {
      await widget.appController.markRewardedShown();
      await c.checkMistakes();
    } else {
      _snack('Ad not completed — check not performed.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Reset board ---------------------------------------------------------

  Future<void> _onReset(RunicSudokuController c) async {
    if (c.completed) return;
    if (!c.hasPlayerProgress) {
      _snack('Nothing to reset.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset board?'),
        content: const Text('Clear all entered runes and notes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) await c.resetBoard();
  }

  // ---- Win + level-complete monetization flow (Phase 3) -------------------

  Future<void> _handleWin() async {
    final c = _controller;
    if (c == null || !mounted) return;
    final solveTime = c.state.actualSolveTime ?? c.elapsed;

    // Record completion first so the win dialog shows the updated streak/stats.
    if (widget.isFreePlay) {
      // Free Play is independent: it records Free Play stats only — never
      // campaign progression or the daily streak.
      await widget.appController
          .onFreePlayCompleted(_activePuzzle.difficultyLabel, solveTime);
      // The session is finished — drop its save slot so it is never offered for
      // resume (Phase 3.66.2). A subsequent "Next Trial" writes a new one.
      await widget.saveService
          .delete(saveKeyFor(PuzzleMode.freePlay, _activePuzzle.levelId));
    } else {
      await widget.progressionController.recordCompletion(
        _activePuzzle.levelId,
        isDaily: widget.isDaily,
        date: DateTime.now(),
      );
      // Daily uses its own dedicated slot — clear it on completion so a finished
      // daily is not offered for resume (Phase 3.66.2 follow-up).
      if (widget.isDaily) {
        await widget.saveService
            .delete(saveKeyFor(PuzzleMode.daily, _activePuzzle.levelId));
      }
    }
    if (!mounted) return;

    final action = await _showWinDialog(c);
    if (!mounted) return;

    // Interstitial only on the level-complete transition, never mid-puzzle.
    // Free Play uses the SAME MonetizationPolicy cadence (every 3rd completion).
    final app = widget.appController;
    if (app.shouldShowInterstitial()) {
      await widget.ads.showInterstitial(placement: 'level_complete');
      await app.markInterstitialShown();
    }
    if (mounted && app.shouldShowRemoveAdsOffer()) {
      await _showRemoveAdsOffer();
      await app.markRemoveAdsOfferShown();
    }
    if (!mounted) return;

    if (widget.isFreePlay) {
      if (action == _WinAction.next) {
        await _startNextTrial();
        return;
      }
      await widget.appController.resetFreePlayStreak();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop(); // back to level select
    }
  }

  /// Free Play: generate the next puzzle of the same difficulty (with the
  /// loading overlay) and swap it in place, restarting the play screen.
  Future<void> _startNextTrial() async {
    final gen = widget.generateNext;
    if (gen == null) return;
    setState(() => _generating = true);
    final next = await gen();
    if (!mounted) return;
    if (next == null) {
      setState(() => _generating = false);
      await _showGenerateError();
      // Generation failed: leave the Free Play loop back to the difficulty
      // select (one pop) and end the streak.
      await widget.appController.resetFreePlayStreak();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    setState(() {
      _activePuzzle = next;
      _controller = null;
      _winShown = false;
      _generating = false;
    });
    await _load();
  }

  Future<void> _showGenerateError() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generation failed'),
        content:
            const Text('Could not generate a puzzle. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<_WinAction> _showWinDialog(RunicSudokuController c) async {
    final extra = widget.isFreePlay
        ? '\nStreak: ${widget.appController.freePlaysCurrentStreak}'
            '${_bestLine()}'
        : (widget.isDaily
            ? '\nDaily streak: ${widget.appController.dailyStreak}'
            : '');
    final action = await showDialog<_WinAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solved!'),
        content: Text(
          'Time: ${_PuzzleHud.format(c.state.actualSolveTime ?? c.elapsed)}\n'
          'Mistakes: ${c.mistakesCount}\n'
          'Hints used: ${c.hintsUsed}'
          '$extra',
        ),
        actions: [
          if (widget.isFreePlay)
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_WinAction.next),
              child: const Text('Next Trial'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_WinAction.cont),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return action ?? _WinAction.cont;
  }

  String _bestLine() {
    final best =
        widget.appController.bestFreePlayTime(_activePuzzle.difficultyLabel);
    if (best == null) return '';
    return '\nBest ${_activePuzzle.difficultyLabel}: '
        '${_PuzzleHud.format(Duration(seconds: best))}';
  }

  Future<void> _showRemoveAdsOffer() async {
    if (!mounted) return;
    final buy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Interstitial Ads?'),
        content: const Text(
            'Enjoying Runic Sudoku? Remove interstitial ads permanently.\n\n'
            'Hints remain available as optional rewarded ads.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove Interstitial Ads'),
          ),
        ],
      ),
    );
    if (buy == true) {
      final res = await widget.purchases.purchaseRemoveAds();
      if (res.isEntitled) await widget.appController.setRemoveAdsPurchased();
      _snack('Remove ads: ${res.status.name}');
    }
  }
}

/// Compact HUD over the grid: time | mistakes | hints. It carries its own dark
/// semi-opaque panel so it stays readable on ANY chapter background (the fill,
/// not the text color, guarantees contrast). Phase 3.60.
class _PuzzleHud extends StatelessWidget {
  final RunicSudokuController controller;
  const _PuzzleHud({required this.controller});

  static const Color _hudText = Color(0xFFF2EAD8);

  static String format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33E0A94A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item(Icons.timer_outlined, format(controller.elapsed)),
          _item(Icons.close, '${controller.mistakesCount}'),
          _item(Icons.lightbulb_outline, '${controller.hintsUsed}'),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: _hudText),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: _hudText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
