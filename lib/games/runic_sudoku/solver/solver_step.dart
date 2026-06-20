import '../../../grid/grid_coordinate.dart';
import 'solving_technique.dart';

/// One step actually performed by the Human-Like Solver: the cell it filled,
/// the technique used, and the value placed.
///
/// The ordered list of these is the `solver_steps_log` from the Phase 0 schema.
class SolverStep {
  final GridCoordinate cell;
  final SolvingTechnique technique;
  final int value;

  const SolverStep({
    required this.cell,
    required this.technique,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'cell': cell.toJson(),
        'technique': technique.wireName,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      other is SolverStep &&
      other.cell == cell &&
      other.technique == technique &&
      other.value == value;

  @override
  int get hashCode => Object.hash(cell, technique, value);

  @override
  String toString() =>
      'SolverStep(${cell.row},${cell.col} ${technique.wireName} = $value)';
}
