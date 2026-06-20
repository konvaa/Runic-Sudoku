import '../solver/difficulty_constants.dart';
import '../solver/human_like_solver.dart';

/// Difficulty policy layer: maps the human-like metrics onto a label and applies
/// the rejection rules. Separated from the solver so the solver stays pure
/// measurement and this stays pure policy.
///
/// As of the complexity-based model, the PRIMARY signal is
/// `candidate_complexity` (Phase 0 §3.1). `decision_points_count` / stall is no
/// longer used for labels or rejection on 6×6 — measured stall rate there is
/// ~0% (see PHASE2_NOTES.md). `unsupported_technique` is unchanged: it still
/// flags puzzles the MVP techniques cannot solve at all, independent of the
/// difficulty axis.
class DifficultyScorer {
  const DifficultyScorer();

  /// The `[lo, hi)` candidate_complexity band for [label].
  (double, double) complexityBand(DifficultyLabel label) {
    switch (label) {
      case DifficultyLabel.quick:
        return (0.0, DifficultyTuning.complexityQuickMax);
      case DifficultyLabel.normal:
        return (DifficultyTuning.complexityQuickMax,
            DifficultyTuning.complexityNormalMax);
      case DifficultyLabel.tricky:
        return (DifficultyTuning.complexityNormalMax,
            DifficultyTuning.complexityTrickyMax);
      case DifficultyLabel.deep:
        return (DifficultyTuning.complexityTrickyMax, double.infinity);
    }
  }

  /// Assigns a label from candidate_complexity, or null when [r] is unsupported
  /// (per spec, no label is assigned in that case).
  DifficultyLabel? classify(HumanLikeResult r) {
    if (r.unsupportedTechnique) return null;
    final c = r.candidateComplexity;
    if (c < DifficultyTuning.complexityQuickMax) return DifficultyLabel.quick;
    if (c < DifficultyTuning.complexityNormalMax) return DifficultyLabel.normal;
    if (c < DifficultyTuning.complexityTrickyMax) return DifficultyLabel.tricky;
    return DifficultyLabel.deep;
  }

  /// True if a puzzle with metrics [r] must be rejected for [target].
  bool isRejectedForTarget(HumanLikeResult r, DifficultyLabel target) =>
      rejectionReason(r, target) != null;

  /// The first failing rejection rule, or null if accepted.
  ///
  /// Rules (Phase 0 §5, re-expressed on the complexity signal):
  ///  1. `unsupported_technique` → reject (cannot be solved by MVP techniques).
  ///  2. complexity outside the target label's band → reject (wrong difficulty).
  String? rejectionReason(HumanLikeResult r, DifficultyLabel target) {
    if (r.unsupportedTechnique) return 'unsupported_technique';
    final got = classify(r);
    if (got != target) {
      return 'complexity_out_of_band(got=${got?.token}, '
          'complexity=${r.candidateComplexity.toStringAsFixed(3)})';
    }
    return null;
  }
}
