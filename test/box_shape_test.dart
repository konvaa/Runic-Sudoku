import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/grid/box_shape.dart';
import 'package:runic_sudoku/grid/grid_coordinate.dart';
import 'package:runic_sudoku/grid/grid_dimensions.dart';

void main() {
  const dims = GridDimensions(rows: 6, cols: 6);
  const shape = BoxShape(rows: 2, cols: 3);

  group('6x6 grid with 2x3 boxes', () {
    test('shape fits the grid and yields 6 boxes', () {
      expect(shape.fits(dims), isTrue);
      expect(shape.boxCount(dims), 6);
      expect(shape.boxesPerRow(dims), 2);
      expect(shape.boxesPerColumn(dims), 3);
    });

    test('every coordinate maps to the mathematically correct box', () {
      for (var r = 0; r < dims.rows; r++) {
        for (var c = 0; c < dims.cols; c++) {
          final coord = GridCoordinate(r, c);
          final expected = (r ~/ 2) * 2 + (c ~/ 3);
          expect(
            shape.boxIndexFor(coord, dims),
            expected,
            reason: 'coordinate $coord should map to box $expected',
          );
        }
      }
    });

    test('all 36 cells are covered, each box holds exactly 6 cells', () {
      final covered = <GridCoordinate>{};
      final counts = List<int>.filled(6, 0);

      for (final coord in dims.coordinates) {
        final idx = shape.boxIndexFor(coord, dims);
        expect(idx, inInclusiveRange(0, 5));
        counts[idx]++;
        covered.add(coord);
      }

      expect(covered.length, 36, reason: 'all 36 distinct cells covered');
      for (var b = 0; b < 6; b++) {
        expect(counts[b], 6, reason: 'box $b should contain 6 cells');
      }
    });

    test('coordinatesInBox returns the exact members of a box', () {
      // Box 0 = top-left 2x3 block.
      expect(
        shape.coordinatesInBox(0, dims).toSet(),
        {
          const GridCoordinate(0, 0),
          const GridCoordinate(0, 1),
          const GridCoordinate(0, 2),
          const GridCoordinate(1, 0),
          const GridCoordinate(1, 1),
          const GridCoordinate(1, 2),
        },
      );
      // Box 5 = bottom-right 2x3 block.
      expect(
        shape.coordinatesInBox(5, dims).toSet(),
        {
          const GridCoordinate(4, 3),
          const GridCoordinate(4, 4),
          const GridCoordinate(4, 5),
          const GridCoordinate(5, 3),
          const GridCoordinate(5, 4),
          const GridCoordinate(5, 5),
        },
      );
    });

    test('box edge detection drives thick borders', () {
      expect(shape.isBoxTopEdge(const GridCoordinate(0, 1)), isTrue);
      expect(shape.isBoxTopEdge(const GridCoordinate(2, 1)), isTrue);
      expect(shape.isBoxTopEdge(const GridCoordinate(1, 1)), isFalse);
      expect(shape.isBoxLeftEdge(const GridCoordinate(1, 3)), isTrue);
      expect(shape.isBoxLeftEdge(const GridCoordinate(1, 4)), isFalse);
    });

    test('token round-trips ("2x3")', () {
      expect(shape.toToken(), '2x3');
      expect(BoxShape.parse('2x3'), shape);
    });
  });
}
