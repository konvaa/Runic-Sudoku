/// Step kinds the difficulty solver can record.
///
/// The MVP deductive techniques are [nakedSingle] and [hiddenSingle]. The enum
/// is left open for future techniques (pointing pairs, box/line reduction, …)
/// which are intentionally NOT implemented in Phase 2 — see PHASE2_NOTES.md.
///
/// [decisionPoint] is NOT a deductive technique: it marks a step where the MVP
/// techniques stalled and the solver had to commit a value it could not deduce
/// (resolved against the known solution). It is recorded so `solver_steps_log`
/// stays a faithful, replayable trace. See the decision-point discussion in
/// PHASE2_NOTES.md.
enum SolvingTechnique {
  nakedSingle,
  hiddenSingle,
  decisionPoint;

  /// Stable snake_case name for logs/serialization.
  String get wireName {
    switch (this) {
      case SolvingTechnique.nakedSingle:
        return 'naked_single';
      case SolvingTechnique.hiddenSingle:
        return 'hidden_single';
      case SolvingTechnique.decisionPoint:
        return 'decision_point';
    }
  }

  /// True for the MVP deductive techniques (not a guessed decision point).
  bool get isDeductive => this != SolvingTechnique.decisionPoint;
}
