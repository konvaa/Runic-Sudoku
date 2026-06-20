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
import 'manual_puzzle.dart';
import 'notes_panel.dart';
import 'progression_controller.dart';
import 'runic_sudoku_controller.dart';
import 'runic_sudoku_symbol_validation.dart';
import 'rune_input_panel.dart';

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
  });

  @override
  State<RunicSudokuScreen> createState() => _RunicSudokuScreenState();
}

class _RunicSudokuScreenState extends State<RunicSudokuScreen>
    with WidgetsBindingObserver {
  RunicSudokuController? _controller;
  bool _winShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final controller = await RunicSudokuController.loadOrCreate(
      puzzle: widget.puzzle,
      saveService: widget.saveService,
      analytics: widget.analytics,
    );
    // Runic Sudoku-specific guard: ensure the active set has enough symbols.
    controller.rules.requireSymbolCount(widget.symbolSet);
    if (!mounted) return;
    setState(() => _controller = controller);
    controller.resume();
    controller.addListener(_onControllerChanged);
    // Remember the most recently opened level (campaign "continue").
    await widget.progressionController.markOpened(widget.puzzle.levelId);
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
        state == AppLifecycleState.inactive) {
      c.pause(); // persists snapshot with app_pause trigger
    } else if (state == AppLifecycleState.resumed) {
      c.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final background = ChapterBackgrounds.forLevel(
      widget.progressionController.progression,
      widget.puzzle.levelId,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.puzzle.difficultyLabel)),
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

  // ---- Win + level-complete monetization flow (Phase 3) -------------------

  Future<void> _handleWin() async {
    final c = _controller;
    if (c == null || !mounted) return;

    // Record completion + re-derive campaign unlocks first, so the win dialog
    // shows the updated streak and the next level is unlocked on return.
    await widget.progressionController.recordCompletion(
      widget.puzzle.levelId,
      isDaily: widget.isDaily,
      date: DateTime.now(),
    );
    if (!mounted) return;

    await _showWinDialog(c);
    if (!mounted) return;

    // Interstitial only on the level-complete transition, never mid-puzzle.
    final app = widget.appController;
    if (app.shouldShowInterstitial()) {
      await widget.ads.showInterstitial(placement: 'level_complete');
      await app.markInterstitialShown();
    }
    if (mounted && app.shouldShowRemoveAdsOffer()) {
      await _showRemoveAdsOffer();
      await app.markRemoveAdsOfferShown();
    }

    if (mounted) Navigator.of(context).pop(); // back to level select
  }

  Future<void> _showWinDialog(RunicSudokuController c) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solved!'),
        content: Text(
          'Time: ${_PuzzleHud.format(c.state.actualSolveTime ?? c.elapsed)}\n'
          'Mistakes: ${c.mistakesCount}\n'
          'Hints used: ${c.hintsUsed}'
          '${widget.isDaily ? '\nDaily streak: ${widget.appController.dailyStreak}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveAdsOffer() async {
    if (!mounted) return;
    final buy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove ads?'),
        content: const Text(
            'Enjoying Runic Sudoku? Remove interstitial ads permanently. '
            'Rewarded hints stay available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove ads'),
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
