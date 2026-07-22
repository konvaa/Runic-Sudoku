// ============================================================================
// DEV-ONLY UX PROTOTYPE — 12×12 board evaluation (Chapter 3 candidate spike).
// Branch: spike/12x12-ux-prototype. NOT reachable from any production route,
// menu, level pool, manifest, or theme registry. May be discarded.
//
// Purpose: answer ONE question — is a 12×12 grid (4×3 boxes, 12 runes)
// readable and playable on a typical Android phone (~360–410dp width) at
// fixed scale, without zoom/pan?
//
// Explicitly out of scope: generator, solver, validity/correctness logic,
// save/load, daily, monetization, progression.
// ============================================================================

import 'package:flutter/material.dart' hide BoxShape;

import '../core/theme/rune_set.dart';
import '../games/runic_sudoku/board_config.dart';
import '../games/runic_sudoku/rune_input_panel.dart';
import '../grid/box_shape.dart';
import '../grid/grid_board_widget.dart';
import '../grid/grid_cell.dart';
import '../grid/grid_coordinate.dart';
import '../grid/grid_dimensions.dart';

/// Chapter 3 candidate board, FOR THIS PROTOTYPE ONLY. Reuses the production
/// [BoardConfig] model (Batch 2) — deliberately NOT registered in any pool,
/// manifest, or theme registry. Box shape follows the "4×3" spike brief with
/// the codebase's rows×cols convention (cf. Chapter 1's 2×3): each box spans
/// 4 rows × 3 columns, tiling 12×12 as 4 box-columns × 3 box-rows.
const BoardConfig devTwelveByTwelve = BoardConfig(
  dimensions: GridDimensions(rows: 12, cols: 12),
  boxShape: BoxShape(rows: 4, cols: 3),
  runeCount: 12,
);

/// PLACEHOLDER symbol set — final 12-rune art/lore is OUT OF SCOPE for this
/// spike. Digits 1–9 + letters A/B/C give an honest legibility floor: real
/// rune glyphs (multi-stroke) will be strictly HARDER to read at the same
/// cell size, so any legibility failure here is conclusive.
const SymbolSet devPlaceholder12Set = SymbolSet(
  id: 'dev_placeholder_12',
  symbols: [
    VisualSymbol(id: 'p1', glyph: '1', displayName: 'One', accessibilityLabel: 'One'),
    VisualSymbol(id: 'p2', glyph: '2', displayName: 'Two', accessibilityLabel: 'Two'),
    VisualSymbol(id: 'p3', glyph: '3', displayName: 'Three', accessibilityLabel: 'Three'),
    VisualSymbol(id: 'p4', glyph: '4', displayName: 'Four', accessibilityLabel: 'Four'),
    VisualSymbol(id: 'p5', glyph: '5', displayName: 'Five', accessibilityLabel: 'Five'),
    VisualSymbol(id: 'p6', glyph: '6', displayName: 'Six', accessibilityLabel: 'Six'),
    VisualSymbol(id: 'p7', glyph: '7', displayName: 'Seven', accessibilityLabel: 'Seven'),
    VisualSymbol(id: 'p8', glyph: '8', displayName: 'Eight', accessibilityLabel: 'Eight'),
    VisualSymbol(id: 'p9', glyph: '9', displayName: 'Nine', accessibilityLabel: 'Nine'),
    VisualSymbol(id: 'pA', glyph: 'A', displayName: 'Ten', accessibilityLabel: 'Ten'),
    VisualSymbol(id: 'pB', glyph: 'B', displayName: 'Eleven', accessibilityLabel: 'Eleven'),
    VisualSymbol(id: 'pC', glyph: 'C', displayName: 'Twelve', accessibilityLabel: 'Twelve'),
  ],
);

/// The prototype play surface: 12×12 board + 12-button input panel, mirroring
/// the production puzzle screen's layout metrics (16dp outer padding, 12dp
/// vertical spacing) so measurements transfer 1:1. Fixed layout — no zoom/pan.
class Dev12x12PrototypeScreen extends StatefulWidget {
  const Dev12x12PrototypeScreen({super.key});

  @override
  State<Dev12x12PrototypeScreen> createState() =>
      _Dev12x12PrototypeScreenState();
}

class _Dev12x12PrototypeScreenState extends State<Dev12x12PrototypeScreen> {
  static const BoardConfig _board = devTwelveByTwelve;

  /// Player grid; 0 = empty. No givens, no correctness — placement UX only.
  late final List<List<int>> _grid = [
    for (var r = 0; r < _board.dimensions.rows; r++)
      List<int>.filled(_board.dimensions.cols, 0),
  ];

  GridCoordinate? _selected;

  /// Board side length as laid out, for the on-screen metrics banner.
  double _boardSide = 0;

  @override
  void initState() {
    super.initState();
    _board.debugAssertValid();
    // A scattering of pre-filled "given-like" cells so legibility can be
    // judged on a partially filled board (values are arbitrary, NOT a valid
    // sudoku position — validity is out of scope).
    var v = 1;
    for (var r = 0; r < 12; r += 2) {
      for (var c = (r ~/ 2) % 3; c < 12; c += 3) {
        _grid[r][c] = (v++ % 12) + 1;
      }
    }
  }

  void _select(GridCoordinate c) => setState(() => _selected = c);

  void _place(int value) {
    final c = _selected;
    if (c == null) return;
    setState(() {
      // Same interaction as production: re-entering the value toggles it off.
      _grid[c.row][c.col] = _grid[c.row][c.col] == value ? 0 : value;
    });
  }

  void _erase() {
    final c = _selected;
    if (c == null) return;
    setState(() => _grid[c.row][c.col] = 0);
  }

  void _clearAll() => setState(() {
        for (final row in _grid) {
          row.fillRange(0, row.length, 0);
        }
      });

  bool _sharesUnit(GridCoordinate a, GridCoordinate b) {
    if (a.row == b.row || a.col == b.col) return true;
    final shape = _board.boxShape;
    final dims = _board.dimensions;
    return shape.boxIndexFor(a, dims) == shape.boxIndexFor(b, dims);
  }

  List<GridCell> _cells() {
    final selected = _selected;
    final selectedValue =
        selected == null ? 0 : _grid[selected.row][selected.col];
    return [
      for (final coord in _board.dimensions.coordinates)
        GridCell(
          coordinate: coord,
          primaryText: _grid[coord.row][coord.col] == 0
              ? null
              : devPlaceholder12Set.forValue(_grid[coord.row][coord.col]).glyph,
          isGiven: false,
          isSelected: coord == selected,
          isHighlighted: selected != null &&
              coord != selected &&
              (_sharesUnit(coord, selected) ||
                  (selectedValue != 0 &&
                      _grid[coord.row][coord.col] == selectedValue)),
          hasError: false,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
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

    final cellDp = _boardSide == 0 ? 0 : _boardSide / 12;

    return Scaffold(
      appBar: AppBar(title: const Text('12×12 UX Prototype (dev)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16), // production screen metric
          child: Column(
            children: [
              // Metrics banner — the point of this spike is measurement.
              Text(
                'viewport ${media.size.width.toStringAsFixed(0)}×'
                '${media.size.height.toStringAsFixed(0)}dp · '
                'board ${_boardSide.toStringAsFixed(0)}dp · '
                'cell ${cellDp.toStringAsFixed(1)}dp '
                '(Material min touch target: 48dp)',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;
                      if (side != _boardSide) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => setState(() => _boardSide = side));
                      }
                      return GridBoardWidget(
                        dimensions: _board.dimensions,
                        boxShape: _board.boxShape,
                        cells: _cells(),
                        style: style,
                        onCellTap: _select,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12), // production screen metric
              RuneInputPanel(
                symbolSet: devPlaceholder12Set,
                count: _board.runeCount, // all 12 buttons, no scrolling aid
                onValue: _place,
                onErase: _erase,
                onReset: _clearAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
