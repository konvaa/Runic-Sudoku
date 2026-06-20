import 'package:flutter/material.dart' hide BoxShape;

import 'box_shape.dart';
import 'grid_cell.dart';
import 'grid_coordinate.dart';
import 'grid_dimensions.dart';
import 'grid_input_mapper.dart';

/// Visual styling for [GridBoardWidget]. Passed in by the host so Grid Core
/// never reaches into the app theme directly.
class GridBoardStyle {
  final Color background;
  final Color cellBorder;
  final Color boxBorder;
  final Color givenText;
  final Color valueText;
  final Color noteText;
  final Color errorText;
  final Color selectedFill;
  final Color highlightFill;
  final double thinLineWidth;
  final double thickLineWidth;

  const GridBoardStyle({
    this.background = Colors.white,
    this.cellBorder = const Color(0xFFBDBDBD),
    this.boxBorder = const Color(0xFF37474F),
    this.givenText = const Color(0xFF212121),
    this.valueText = const Color(0xFF1565C0),
    this.noteText = const Color(0xFF757575),
    this.errorText = const Color(0xFFC62828),
    this.selectedFill = const Color(0x3340C4FF),
    this.highlightFill = const Color(0x14000000),
    this.thinLineWidth = 1.0,
    this.thickLineWidth = 2.5,
  });
}

/// Renders a grid plus its box boundaries and per-cell content, and reports
/// taps as [GridCoordinate]s. Knows nothing about sudoku rules — it just draws
/// the [GridCell]s it is given.
class GridBoardWidget extends StatelessWidget {
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final List<GridCell> cells;
  final ValueChanged<GridCoordinate>? onCellTap;
  final GridBoardStyle style;

  const GridBoardWidget({
    super.key,
    required this.dimensions,
    required this.boxShape,
    required this.cells,
    this.onCellTap,
    this.style = const GridBoardStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final mapper = GridInputMapper(dimensions);
    return AspectRatio(
      aspectRatio: dimensions.cols / dimensions.rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onCellTap == null
                ? null
                : (details) {
                    final coord = mapper.coordinateForOffset(
                      details.localPosition,
                      size,
                    );
                    if (coord != null) onCellTap!(coord);
                  },
            child: CustomPaint(
              size: size,
              painter: _GridPainter(
                dimensions: dimensions,
                boxShape: boxShape,
                cells: cells,
                style: style,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final GridDimensions dimensions;
  final BoxShape boxShape;
  final List<GridCell> cells;
  final GridBoardStyle style;

  _GridPainter({
    required this.dimensions,
    required this.boxShape,
    required this.cells,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / dimensions.cols;
    final cellH = size.height / dimensions.rows;

    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = style.background,
    );

    // Cell fills (selection / highlight) and content.
    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        cell.coordinate.col * cellW,
        cell.coordinate.row * cellH,
        cellW,
        cellH,
      );
      if (cell.isSelected) {
        canvas.drawRect(rect, Paint()..color = style.selectedFill);
      } else if (cell.isHighlighted) {
        canvas.drawRect(rect, Paint()..color = style.highlightFill);
      }
      _paintCellContent(canvas, rect, cell);
    }

    // Thin cell grid lines.
    final thin = Paint()
      ..color = style.cellBorder
      ..strokeWidth = style.thinLineWidth
      ..style = PaintingStyle.stroke;
    for (var r = 0; r <= dimensions.rows; r++) {
      canvas.drawLine(Offset(0, r * cellH), Offset(size.width, r * cellH), thin);
    }
    for (var c = 0; c <= dimensions.cols; c++) {
      canvas.drawLine(Offset(c * cellW, 0), Offset(c * cellW, size.height), thin);
    }

    // Thick box boundary lines.
    final thick = Paint()
      ..color = style.boxBorder
      ..strokeWidth = style.thickLineWidth
      ..style = PaintingStyle.stroke;
    for (var r = 0; r <= dimensions.rows; r += boxShape.rows) {
      canvas.drawLine(
          Offset(0, r * cellH), Offset(size.width, r * cellH), thick);
    }
    for (var c = 0; c <= dimensions.cols; c += boxShape.cols) {
      canvas.drawLine(
          Offset(c * cellW, 0), Offset(c * cellW, size.height), thick);
    }
    // Outer frame is always thick.
    canvas.drawRect(Offset.zero & size, thick);
  }

  void _paintCellContent(Canvas canvas, Rect rect, GridCell cell) {
    if (cell.primaryText != null && cell.primaryText!.isNotEmpty) {
      final color = cell.hasError
          ? style.errorText
          : (cell.isGiven ? style.givenText : style.valueText);
      final tp = TextPainter(
        text: TextSpan(
          text: cell.primaryText,
          style: TextStyle(
            color: color,
            fontSize: rect.height * 0.6,
            fontWeight: cell.isGiven ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        rect.center - Offset(tp.width / 2, tp.height / 2),
      );
    } else if (cell.noteMarks.isNotEmpty) {
      _paintNotes(canvas, rect, cell.noteMarks);
    }
  }

  void _paintNotes(Canvas canvas, Rect rect, List<String> marks) {
    // Lay notes out in a 3-column grid inside the cell.
    const perRow = 3;
    final noteW = rect.width / perRow;
    final noteH = rect.height / perRow;
    for (var i = 0; i < marks.length; i++) {
      final r = i ~/ perRow;
      final c = i % perRow;
      final tp = TextPainter(
        text: TextSpan(
          text: marks[i],
          style: TextStyle(color: style.noteText, fontSize: noteH * 0.7),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cellCenter = Offset(
        rect.left + noteW * (c + 0.5),
        rect.top + noteH * (r + 0.5),
      );
      tp.paint(canvas, cellCenter - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cells != cells ||
      old.dimensions != dimensions ||
      old.boxShape != boxShape ||
      old.style != style;
}
