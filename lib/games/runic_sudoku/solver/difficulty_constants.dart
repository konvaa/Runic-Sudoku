/// Difficulty labels (Phase 0 section 3.2).
///
/// All four are reachable on 6×6, but [deep] is COSTLY there: it only appears at
/// near-minimal puzzles (~26–28 blanks, complexity >= 0.30), so it needs many
/// more generation attempts than the others (measured ~30–65 vs ~1). The MVP
/// therefore ships a pre-generated pool rather than generating Deep on-device.
/// (An earlier note wrongly called Deep "unreachable" — that was an artifact of a
/// diagnostic sweep that only sampled to 25 blanks.) See PHASE2_NOTES.md
/// "Follow-up #3".
enum DifficultyLabel {
  quick,
  normal,
  tricky,
  deep;

  String get token {
    switch (this) {
      case DifficultyLabel.quick:
        return 'Quick';
      case DifficultyLabel.normal:
        return 'Normal';
      case DifficultyLabel.tricky:
        return 'Tricky';
      case DifficultyLabel.deep:
        return 'Deep';
    }
  }

  static DifficultyLabel fromToken(String token) {
    return DifficultyLabel.values.firstWhere(
      (l) => l.token == token,
      orElse: () =>
          throw ArgumentError('Unknown difficulty label token: "$token"'),
    );
  }
}

/// ALL tunable difficulty heuristics in ONE place.
///
/// The thresholds below were derived from MEASURED 6×6 data (real output of
/// `tool/difficulty_metric_exploration.dart`, 100 carved unique puzzles per
/// blank fraction), not from theory:
///
/// ```
/// frac  avgBlank  candidate_complexity   max_candidates
/// 0.20  7.0       0.000                  1.48
/// 0.30  11.0      0.003                  2.05
/// 0.40  14.0      0.015                  2.56
/// 0.45  16.0      0.027                  2.88
/// 0.50  18.0      0.053                  3.24
/// 0.55  20.0      0.086                  3.69
/// 0.60  22.0      0.122                  4.00
/// 0.65  23.0      0.151                  4.28
/// 0.70  25.0      0.204                  4.49
/// ```
///
/// `candidate_complexity` is the PRIMARY difficulty signal (Pearson r=0.93 with
/// blank fraction; monotone). `stall`/`decision_points_count` was dropped as a
/// signal (stall rate stayed 0.0–1.0% across the whole range — non-existent on
/// 6×6). These remain placeholders, tunable here in one place.
class DifficultyTuning {
  const DifficultyTuning._();

  // ---- Primary signal: candidate_complexity thresholds -------------------
  // Boundaries chosen between measured complexity plateaus so adjacent labels
  // map to clearly separated blank-fraction ranges:
  //   Quick  : complexity <  0.03   (frac ~0.20–0.45, complexity ~0.00–0.027)
  //   Normal : 0.03 .. <0.10        (frac ~0.50–0.55, complexity ~0.053–0.086)
  //   Tricky : 0.10 .. <0.30        (frac ~0.60–0.70, complexity ~0.122–0.204)
  //   Deep   : >= 0.30              (reachable on 6×6 only at near-minimal
  //                                  puzzles ~0.30–0.34; costly to generate)
  static const double complexityQuickMax = 0.03;
  static const double complexityNormalMax = 0.10;
  static const double complexityTrickyMax = 0.30;

  // ---- estimated_solve_time = base + complexity * scale (seconds) ---------
  // Deliberately driven by candidate_complexity, NOT by blank/forced-move count,
  // so a harder puzzle reads as longer (Quick < Normal < Tricky), instead of the
  // old "more blanks = longer" inversion. Validated on the table above in
  // PHASE2_NOTES.md.
  static const double estBaseSeconds = 30;
  static const double estComplexityScaleSeconds = 1200;

  // ---- Stall threshold N (used ONLY for unsupported_technique, not labels) -
  static const int decisionPointCellThreshold = 3;

  // ---- Generator removal: blank fraction to aim past per label -----------
  // The band-targeting remover keeps removing until complexity enters the target
  // band; this fraction is an upper bound / starting hint. Quick stops early
  // (low complexity), Tricky needs near-minimal puzzles.
  static const Map<DifficultyLabel, double> targetBlankFraction = {
    DifficultyLabel.quick: 0.45,
    DifficultyLabel.normal: 0.55,
    DifficultyLabel.tricky: 0.70,
    DifficultyLabel.deep: 0.80, // costly on 6×6 (near-minimal puzzles)
  };

  // ---- Phase 0 display time bands (informational only, NOT a rejection gate)
  static const Map<DifficultyLabel, (int, int)> timeBandsSeconds = {
    DifficultyLabel.quick: (30, 120),
    DifficultyLabel.normal: (60, 180),
    DifficultyLabel.tricky: (180, 360),
    DifficultyLabel.deep: (300, 600),
  };
}
