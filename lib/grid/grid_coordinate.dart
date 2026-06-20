/// A single (row, column) position on a grid.
///
/// Pure data, agnostic to any game rules. `row` and `col` are zero-based.
class GridCoordinate {
  final int row;
  final int col;

  const GridCoordinate(this.row, this.col);

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory GridCoordinate.fromJson(Map<String, dynamic> json) =>
      GridCoordinate(json['row'] as int, json['col'] as int);

  @override
  bool operator ==(Object other) =>
      other is GridCoordinate && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'GridCoordinate(r$row, c$col)';
}
