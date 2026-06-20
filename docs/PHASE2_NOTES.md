# Runic Sudoku — Phase 2 implementation notes

> **Latest update — the difficulty model is now `candidate_complexity`-based.**
> Measured data (`tool/difficulty_metric_exploration.dart`) showed the stall /
> `decision_points_count` signal is ~0 across the whole blank range on 6×6, so it
> was dropped as the difficulty axis and replaced by `candidate_complexity`. The
> full rationale, data, thresholds, new `estimated_solve_time` formula, rejection
> rules and the 3-levels-on-6×6 conclusion are in **"Follow-up #2:
> complexity-based difficulty model"** at the very bottom. The earlier
> decision-point write-ups below are kept for history but are superseded.
>
> **Follow-up #1 (Normal-generation fix).** A `flutter test` run failed with
> `Failed to generate a Normal puzzle within 300 attempts` — a real bug. The
> decision-point model change and constant recalibration are in
> **"Follow-up: diagnosing and fixing non-Quick generation"**. I could not run
> the sweeps in this environment (sandbox unavailable); the diagnostics
> (`dart run tool/calibrate_difficulty.dart`, `tool/difficulty_metric_exploration.dart`)
> produce the numbers to confirm.

Two solvers + a generator + their tests, built on the Phase 1 data models and
pure Dart (no Flutter/UI, no external dependencies). No universal constraint
engine, no sudoku-variant system, no hint-UI integration (that is Phase 3).

This follows the Phase 1 output order: architecture plan, data models, code
skeleton (in `/lib/games/runic_sudoku/solver` and `/generator`), tests, what is
intentionally not implemented, the decisions made, deferred ideas, and
specification ambiguities.

## 1. Architectural plan

Two new sub-packages inside the existing game module, both reusing the Phase 1
grid types (`GridCoordinate`, `GridDimensions`, `BoxShape`) and `RunicSudokuRules`:

- **`/solver`** — `FastUniquenessSolver` (speed-first solution counter),
  `HumanLikeSolver` (difficulty measurement), plus shared types `SolverStep`,
  `SolvingTechnique`, and the single tuning file `difficulty_constants.dart`.
- **`/generator`** — `FullGridGenerator` (randomized backtracking fill),
  `CellRemover` (removal with uniqueness checks), `DifficultyScorer` (label +
  rejection policy), `LevelData` (canonical JSON), and `PuzzleGenerator` (the
  pipeline).

Dependency direction stays clean: solver depends only on grid core; generator
depends on solver + grid core; nothing here touches App Core or UI. Everything
is plain Dart and runs outside Flutter.

A required Phase-1 change was needed first (see "Specification ambiguities"):
`RunicSudokuRules` transitively imported Flutter through `SymbolSet`. Its
`requireSymbolCount` method was moved into a new
`runic_sudoku_symbol_validation.dart` extension, so the rules — and the solvers
reusing them — are now pure Dart.

## 2. Data models

- `SolvingTechnique` — enum `{ nakedSingle, hiddenSingle }` (MVP only, left open).
- `SolverStep` — `{ GridCoordinate cell, SolvingTechnique technique, int value }`,
  the ordered entries of `solver_steps_log`.
- `HumanLikeResult` — `forced_moves_count`, `decision_points_count`,
  `candidate_complexity`, `estimated_solve_time`, `difficulty_score`,
  `unsupported_technique`, `solver_steps_log`, plus `solved`.
- `DifficultyLabel` — `{ quick, normal, tricky, deep }` with `Quick/Normal/…`
  tokens.
- `DifficultyTuning` — all placeholder heuristic constants in one place.
- `LevelData` — `{ grid_size, box_shape, solution_grid, given_cells,
  difficulty_label, seed? }`; canonical data is the two grids, `seed` is debug
  only.
- `GenerationResult` — `{ level, metrics, attempts, seedUsed }`.

## 3 & 4. Code skeleton and tests

Source under `/lib/games/runic_sudoku/solver` and `/generator`; tests under
`/test`:

- `fast_uniqueness_solver_test.dart` — unique→1, multi→2, invalid→0, and an
  early-stop check (the cap controls the result and the node count).
- `human_like_solver_test.dart` — trivial (forced>0, decisions==0,
  not unsupported), a hidden-single decision point (decisions>0), an unsupported
  puzzle (no label), and step-log fidelity. These use a **4×4 / 2×2** grid: small
  enough to hand-trace and a live demonstration that the solver is parametric.
- `puzzle_generator_test.dart` — full grid valid, generated Quick puzzle unique +
  zero decision points, generated non-Quick puzzle with decisions>0, JSON
  round-trip, and the rejection rules tested directly.

Run with `flutter test`. The solver/generator code imports zero Flutter; to run
just those under plain `dart test` you would only need to add the `test` package
to `dev_dependencies` — intentionally not done, to honor the no-new-dependencies
rule and stay consistent with the Phase 1 test harness.

## 5. Intentionally NOT implemented (per the brief)

No solving techniques beyond naked/hidden single (no pointing pairs, box/line
reduction, X-Wing, etc.). No general constraint-solver engine, no sudoku variants
(Killer/Jigsaw/diagonal), no irregular box shapes, no elementary constraints, no
multi-region puzzles, no 9×9-specific logic, and no hint-system UI. The code is
parametric over size/box shape but adds nothing that enables other sizes.

## Implementation decisions I made

- **Decision-point model (N=3) — UPDATED in the follow-up.** A **decision point
  is a stall**: a step where neither a naked nor a hidden single is available and
  the puzzle is unsolved, occurring while the board is still complex (more than
  `N = 3` empty cells have ≥2 candidates). To pass the stall without a
  backtracking solver (out of scope), the solver commits the **known solution
  value** at the minimum-remaining-values cell and continues. So
  `decision_points_count` = the number of non-deducible steps on the path to the
  solution — small integers that match the Phase 0 ranges (Quick 0, Normal 1–2,
  Tricky 2–4, Deep 4+). `unsupported_technique` is set for a contradiction, a
  too-tight stall (≤ N complex cells), or givens inconsistent with the solution.
  `N` lives in `DifficultyTuning.decisionPointCellThreshold`. *(The original
  Phase 2 draft counted "a hidden single in a complex board"; that produced
  ≈0 decision points on dense 6×6 boards and made Normal ungeneratable — see the
  follow-up section.)* **Flagged for review before Phase 3.**
- **`SolverStep` / `solver_steps_log` structure.** Exactly `{cell, technique,
  value}` as specified, in execution order. `technique` is `nakedSingle`,
  `hiddenSingle`, or `decisionPoint` (the last marks a committed, non-deduced
  value at a stall, so the log stays a faithful, replayable trace). Replaying the
  log onto the givens reproduces the full solution.
- **Target blank count per label.** `DifficultyTuning.targetBlankFraction` gives
  a removal *aim* as a fraction of all cells (Quick maximal, Normal 0.42, Tricky
  0.52, Deep 0.60 — a fraction so it stays grid-size agnostic; raised in the
  follow-up). This is only the removal target; the **real difficulty gate is the
  human-like scorer + rejection rules**, not the blank count. Quick is
  special-cased: it removes maximally while the puzzle stays a zero-decision
  single cascade, rather than stopping at a
  fixed fraction, so it reliably clears the Quick time floor.
- **`difficulty_score` formula.** Phase 0 lists the field but defines no formula
  (see ambiguities). I use a documented placeholder composite:
  `forced·1 + decisions·5 + complexity·20`, with the weights in `DifficultyTuning`.
- **`T_forced` / `T_decision` / `T_complexity` recalibration (follow-up).** Phase 0
  gave 3 / 12 / 30 as explicit placeholders. On a 36-cell grid those cap the
  achievable `estimated_solve_time` below the Tricky/Deep band minima (Deep's
  240 s floor is unreachable). They were scaled to 6 / 24 / 60 so the achievable
  range spans all four Phase 0 *bands* (which are unchanged) on 6×6. See the
  follow-up section; **flagged for review.**
- **`AdResult`-style result vs exception.** The fast solver returns `int`
  (0/1/2) and exposes `nodesVisited`; the human solver returns a value object.
  No exceptions on "unsolvable" — those are normal outcomes.
- **Parametricity — confirmed.** The fast solver, human solver, full-grid
  generator and remover all derive `n`, box count, per-cell box index and bit
  masks from `GridDimensions`/`BoxShape`; nothing is hardcoded to 6 or `2×3`. The
  human-solver tests run on 4×4/2×2 to prove this. The only place `6×6`/`2×3`
  appears literally is as **default constructor arguments** for `PuzzleGenerator`
  (convenience for the MVP game) and in `RunicSudokuRules.sixBySix`; both are
  overridable. No size-specific branching exists anywhere.

## Not implemented / deferred ideas

- **Additional techniques (pointing pairs, box/line reduction, X-Wing).**
  *Useful:* would let the solver rate harder puzzles instead of marking them
  unsupported. *Not now:* explicitly out of MVP scope and would expand the
  difficulty model. *Later:* Phase 3+, by adding enum values and technique passes
  ordered after hidden single.
- **Incremental/persistent uniqueness state.** *Useful:* avoids re-deriving masks
  per removal check. *Not now:* premature for 6×6 (see performance note).
  *Later:* if larger grids or batch generation make it a bottleneck.
- **Difficulty model from real telemetry.** *Useful:* replace placeholder
  constants with data-fit values. *Not now:* no data yet. *Later:* once solve-time
  telemetry exists, retune `DifficultyTuning` only.
- **Symmetric clue removal / aesthetic puzzles.** *Useful:* nicer-looking givens.
  *Not now:* not required and constrains the generator. *Later:* optional removal
  strategy.

## Specification ambiguities

- **`RunicSudokuRules` pulled in Flutter (Phase 1 vs Phase 2 conflict).** Reusing
  the rules in a pure-Dart solver was impossible because `requireSymbolCount`
  imported `SymbolSet → VisualSymbol → Color`. *Resolution:* a minimal,
  non-invasive change — moved that one method into a
  `runic_sudoku_symbol_validation.dart` extension and removed the import from the
  rules. Behavior unchanged; the screen now imports the extension. **Review:**
  already applied and low-risk, but worth a confirming glance.
- **Decision-point definition.** The literal definition implies lookahead /
  guessing. The first Phase 2 draft avoided that with "hidden single in a complex
  board", but that produced ≈0 decision points on dense 6×6 boards and made
  Normal ungeneratable. The follow-up adopts a **stall + solution-assisted**
  model (count the non-deducible steps; commit the known solution value to
  continue — no backtracking search). This matches the spec's stated ranges and
  generates reliably, but it does mean the "human-like" solver consults the
  solution to step past stalls. **Review before Phase 3:** yes — this is the most
  consequential interpretation and was changed once already.
- **`difficulty_score` undefined.** Phase 0 lists the field with no formula. I
  defined a placeholder composite. **Review:** confirm the intended formula before
  it feeds any player-facing display.
- **Overlapping label bands.** Phase 0 §3.2 bands overlap on decision points
  ("1–2", "2–4", "4+") and on time. The generator generates *for* a target and
  gates on that target's rejection rules, so it does not need to disambiguate;
  the standalone `classify()` resolves overlaps with non-overlapping
  decision-point thresholds (0 / 1–2 / 3–4 / 5+). **Review:** confirm the desired
  classifier if labels are ever inferred rather than targeted.
- **`box_shape` / `grid_size` tokens.** Consistent with Phase 1: structured types
  internally, `"2x3"` / `"6x6"` on the wire. No review needed.
- **`given_cells` shape.** Reused the Phase 1 convention (`List<List<int>>`,
  0 = empty). No review needed.

## Performance note (uniqueness checks)

`CellRemover` reuses a single `FastUniquenessSolver` across all removal checks in
a run. The per-cell box index is precomputed once in the solver constructor; each
`countSolutions` call allocates O(n²) working arrays (one flat board + three
small mask lists) and rebuilds masks from the givens. For 6×6 (36 cells) over the
tens–hundreds of checks per puzzle this is negligible, so I deliberately did
**not** build an incremental/persistent constraint structure — that would be
premature optimization for MVP sizes and add complexity. If profiling on larger
grids ever shows it matters, the masks can be made incremental behind the same
`countSolutions` API without touching callers.

## Follow-up: diagnosing and fixing non-Quick generation

**Symptom.** `flutter test` → `Bad state: Failed to generate a Normal puzzle
within 300 attempts.` Real bug, not flakiness.

**Measurement caveat.** I could not run the empirical sweep in this environment
(the sandbox was unavailable), so the analysis below is mechanism-based and the
constants are derived, not measured. `tool/calibrate_difficulty.dart`
(`dart run tool/calibrate_difficulty.dart`) prints exactly the numbers asked for —
the decision-point histogram and unsupported rate per blank fraction (over 100
carved candidates, before rejection rules), plus the real attempts-per-label of
the full generator. Run it to confirm and to retune with evidence.

**Diagnosis — two compounding problems.**

1. *Decisions were almost never produced (the immediate failure).* The original
   model counted a decision point only when a **hidden** single was applied while
   >3 cells were still complex. But (a) at Normal's old 0.33 fraction (~12 blanks
   on 36 cells) the givens are dense, so most empty cells have a single candidate
   and the board is rarely "complex"; and (b) naked singles are applied before
   hidden singles, so "hidden-single-in-complex" is intrinsically rare on a small
   6×6. Net: `decision_points_count` ≈ 0 → rejection rule 2 (non-Quick needs
   decisions > 0) rejects every candidate → 300 attempts exhausted. This is a
   *definition* problem, amplified by a low blank fraction — both N and the
   fraction were implicated, exactly the two suspects called out in the brief.

2. *Economics ceiling (would block Tricky/Deep even after #1).* With
   `T_forced = 3 s` on 36 cells, the maximum achievable `estimated_solve_time` is
   ~180–216 s. Tricky's floor (144 s) is reachable at the edge, but **Deep's
   240 s floor is mathematically unreachable** on 6×6 with the Phase 0
   placeholder constants. So Deep could never pass rejection rule 3.

**Fixes applied (no scope change; Phase 0 bands untouched).**

- *Decision-point definition → stall + solution-assisted* (the brief's option 3,
  applied transparently, not silently). A decision point is now a genuine stall
  (no naked/hidden single, puzzle unsolved) in a complex board (>N=3 cells with
  ≥2 candidates), stepped past by committing the known solution value at the MRV
  cell — no backtracking search. This makes decisions rare, small integers that
  track real difficulty (Quick 0, Normal 1–2, …) and scale with blank count, so
  non-Quick becomes reliably generatable. `unsupported_technique` now means a
  contradiction, a too-tight (≤N) stall, or givens inconsistent with the solution.
- *Blank fractions raised* (`DifficultyTuning.targetBlankFraction`): Normal
  0.33→0.42, Tricky 0.45→0.52, Deep 0.55→0.60. Quick still removes maximally
  while staying a zero-decision cascade.
- *Placeholder T-constants scaled* 3/12/30 → 6/24/60 so the achievable est range
  spans all four Phase 0 bands on 6×6 (otherwise Deep is impossible). These are
  the explicitly-tunable MVP placeholders; the Phase 0 bands themselves are
  unchanged.
- *`SolvingTechnique.decisionPoint`* added so committed decision steps appear in
  `solver_steps_log` (the log stays a faithful, replayable trace).
- *`test/widget_test.dart`* replaced (it referenced the non-existent `MyApp` from
  the `flutter create` scaffold) with a real app-shell smoke test.

**Is the decision-point definition/calibration ready for review, or still open?**
Still **open** — the definition was changed once and the constants are derived,
not measured. The structural fix (stall-counting) is sound and Quick/Normal
should now generate comfortably; Tricky and especially Deep depend on the
recalibrated constants and higher fractions, which need the diagnostic tool's
numbers to finalize. Recommended next step before Phase 3: run
`tool/calibrate_difficulty.dart`, confirm each label generates in a low number of
attempts (not at the cap), and adjust the fractions/constants in
`difficulty_constants.dart` if any label is rare. If Deep still cannot reach its
240 s floor at acceptable rates, that is the fundamental 6×6-is-small finding —
the realistic resolutions are to further tune the (placeholder) T-constants or to
accept that Deep targets larger grids; either is a call to make with the
measured data, not silently.

## Follow-up #2: complexity-based difficulty model

**Measured data** (real output of `tool/difficulty_metric_exploration.dart`, 100
carved unique puzzles per blank fraction, pre-rejection):

```
frac  avgBlank  stall%  hiddenRatio  maxCands  candidate_complexity
0.20  7.0       0.0     0.000        1.48      0.000
0.30  11.0      0.0     0.000        2.05      0.003
0.40  14.0      0.0     0.000        2.56      0.015
0.45  16.0      0.0     0.000        2.88      0.027
0.50  18.0      0.0     0.000        3.24      0.053
0.55  20.0      0.001   0.001        3.69      0.086
0.60  22.0      0.0     0.003        4.00      0.122
0.65  23.0      0.0     0.011        4.28      0.151
0.70  25.0      1.0     0.037        4.49      0.204
Pearson r vs frac: stall 0.50, steps 0.999(==blanks), hidden 0.646,
                   maxCands 0.997, candidate_complexity 0.929
```

**Decision (driven by this data):**

- **Drop stall / `decision_points_count` as the difficulty axis on 6×6.** Its
  rate is 0.0–1.0% across the entire range — the phenomenon barely exists on a
  6-value grid, independent of how it is defined. The field/type is **kept** in
  `HumanLikeResult` and `SolvingTechnique` as a secondary metric for a future
  9×9 (where stalls do occur), but it no longer feeds labels or rejection.
- **Primary signal = `candidate_complexity`** (Phase 0 §3.1, normalized 0–1),
  monotone with blank fraction (r=0.93).
- **No `max_candidates` blend.** `max_candidates` is the only other signal that
  also discriminates the *easy* end (where complexity is flat ≈0). But the easy
  end is degenerate precisely because those puzzles are all trivial; rather than
  add a second signal to split trivia, I **merge the trivial easy tiers into one
  level**. Once merged, every remaining label boundary sits in the region where
  `candidate_complexity` is already discriminative — so the blend isn't needed.
  (`max_candidates` is still exposed in `HumanLikeResult` for future tuning, but
  unused by the model — combining "only because it's available" was avoided, per
  the brief.)

**Label thresholds (on `candidate_complexity`), from the plateaus above:**

| label | complexity band | maps to (data) |
|---|---|---|
| Quick  | `< 0.03`        | frac ~0.20–0.45 (complexity 0.000–0.027) |
| Normal | `0.03 – <0.10`  | frac ~0.50–0.55 (0.053–0.086) |
| Tricky | `0.10 – <0.30`  | frac ~0.60–0.70 (0.122–0.204) |
| Deep   | `>= 0.30`       | reachable only at near-minimal puzzles (~26–28 blanks) |

> **CORRECTION (see Follow-up #3).** This section originally claimed Deep was
> "not reachable on 6×6 (ceiling ~0.20)" and that 6×6 supports only three levels.
> That was **wrong** — an artifact of the exploration sweep only sampling up to
> 25 blanks. The actual generator carves to near-minimal puzzles (~26–28 blanks)
> where complexity reaches ~0.30–0.34, so **all four labels are reachable on
> 6×6**; Deep is just costly to generate (~30–65 attempts vs ~1). Details below.

**New `estimated_solve_time` = `base + candidate_complexity × scale`**
(`base = 30 s`, `scale = 1200 s`), deliberately independent of blank/forced-move
count so it tracks difficulty, not emptiness. Validated on the measured means:

```
frac  complexity  est = 30 + 1200·complexity   label
0.30  0.003       33.6 s                        Quick
0.45  0.027       62.4 s                        Quick
0.50  0.053       93.6 s                        Normal
0.55  0.086       133.2 s                       Normal
0.60  0.122       176.4 s                       Tricky
0.70  0.204       274.8 s                       Tricky
```

Ordering is now correct: Quick (≈30–62 s) < Normal (≈94–133 s) < Tricky
(≈176–275 s). This fixes the old inversion where Quick (most blanks) had the
highest estimate.

**Rejection rules (re-expressed on the new signal):** (1) `unsupported_technique`
→ reject (unchanged — still "MVP can't solve it at all", independent of
difficulty); (2) the puzzle's complexity must classify to the requested label,
else reject. The old "decision_points == 0 for non-Quick" rule is gone.

**Generator:** now carves by **band targeting** — it removes clues (keeping
uniqueness and MVP-solvability) until `candidate_complexity` lands in the target
label's band, returning the most-carved in-band puzzle. Because complexity rises
as clues are removed, one full grid usually yields the band directly, so
Quick/Normal/Tricky generate in ~1 attempt. Deep on 6×6 is reachable but costly
(~30–65 attempts; it lives at near-minimal puzzles), so the MVP pre-generates it
offline — see Follow-up #3.

**Verification status (honest).** The sandbox is still unavailable, so I could
not run `flutter test` or the tools myself. I hand-validated the thresholds, the
`est` ordering, and the 4×4 solver fixtures against the measured table above.
Please run `flutter test`, `dart run tool/calibrate_difficulty.dart`, and
`tool/difficulty_metric_exploration.dart` (now also prints per-fraction standard
deviation, so you can check band-separation vs noise).

**Is the model stable or still under review?** I consider it **stable for 6×6**:
it is grounded in measured data, the three levels are cleanly separated by the
means, and the generator filters on `classify == target`, so even if a label's
within-fraction spread overlaps a neighbour, emitted puzzles are still correctly
labelled (only the attempt count rises). The one open item to confirm with the
new stddev output: if Normal/Tricky spreads turn out wide, raise `maxAttempts`
or nudge the target blank fractions — no structural change needed.

(The "Deep is out of scope on 6×6" remark that was here is retracted — see the
correction in Follow-up #3.)

## Follow-up #3: Deep IS reachable on 6×6 — correction + pre-generated pool

**What was wrong.** Follow-ups #1–#2 stated Deep was "unreachable on 6×6"
(complexity ceiling ~0.20) and that 6×6 supports only three levels. Running the
generator (which I finally could — sandbox returned, Python available, Dart not)
disproved it.

**Root cause of the error.** The exploration sweep
(`difficulty_metric_exploration.dart`) only samples blank fraction up to 0.70 =
25 blanks, where complexity ≈ 0.20. I mistook that sweep endpoint for a true
ceiling. The actual generator's Deep carve has band `[0.30, ∞)` (no upper cap),
so it removes down to **near-minimal puzzles (~26–28 blanks)** where complexity
climbs to **~0.30–0.34**. So Deep is reachable, and all four labels exist on 6×6.

**Measured generation cost** (faithful Python port of the generator; the port was
validated to reproduce the user's real Dart sweep numbers — complexity 0.000→0.208
vs the Dart 0.000→0.204, stall ~0 throughout):

```
label    success           avg attempts   avg complexity   avg blanks   avg est
Quick    100%              1.0            0.024            ~21          ~59 s
Normal   100%              1.0            0.091            ~23          ~140 s
Tricky   100%              1.0            0.215            ~25          ~288 s
Deep     8/8 @ maxAtt=250  ~30–65         0.309            ~26.5        ~401 s
```

Deep needs ~30–65× the attempts of the others. At a runtime-style budget
(maxAttempts≈60) it's ~90% (≈22 avg, matching the user's `calibrate` run); at an
offline budget (250) it's ~100%.

**Decision: ship a pre-generated, cached level pool** (confirmed with the user).
On-device, the 6×6 MVP reads a static pool instead of generating on demand —
appropriate for a fixed level set + daily puzzle, and it removes Deep's latency /
failure risk from the client. Runtime `PuzzleGenerator` is unchanged and stays
available (future daily-puzzle / 9×9).

**Deliverables added (no runtime logic changed):**

- `tool/generate_level_pool.dart` — canonical offline generator. Builds N puzzles
  per label (20/20/20 Quick/Normal/Tricky, 10 Deep; Deep at `maxAttempts = 250`)
  and writes `assets/levels/runic_sudoku_levels.json` via the existing `LevelData`
  format. Run: `dart run tool/generate_level_pool.dart`.
- `assets/levels/runic_sudoku_levels.json` — committed reference pool, **70
  puzzles** (20/20/20/10). Registered in `pubspec.yaml` assets.
- `LevelData` gained an optional `estimatedSolveTime` field (the only model
  change — a data field, not generator logic) so each pool entry carries
  `estimated_solve_time`. `PuzzleGenerator` now populates it on its output
  `LevelData`.

**How the committed JSON was produced (honest).** The sandbox has **no Dart SDK**,
so I could not run `tool/generate_level_pool.dart` or `flutter test` here. The
committed `runic_sudoku_levels.json` was generated by the **validated Python port**
running the identical algorithm/thresholds, and **every one of the 70 puzzles was
re-validated** (valid solution; givens ⊆ solution; unique solution via the
uniqueness solver; complexity classifies to its label; `est` matches the formula)
— 0 errors. Measured pool ranges:

```
Quick   blanks 19–22  complexity 0.023–0.026
Normal  blanks 21–24  complexity 0.083–0.098
Tricky  blanks 23–27  complexity 0.120–0.288
Deep    blanks 26–28  complexity 0.304–0.343
```

To get byte-canonical output from the Dart generator itself, run the Dart script
once a Dart SDK is available; it produces the same schema. **Please run
`flutter test`** — I could not (no Dart in sandbox). The changes touching app code
are minimal (the optional `LevelData.estimatedSolveTime` and its one-line
population in `PuzzleGenerator`), and the existing `LevelData` round-trip test
still asserts the same fields.

**Recommendation on offering Deep at 6×6.** Keep it — the pre-generated pool makes
Deep's generation cost a non-issue on-device, and Deep puzzles are legitimately
the hardest single-solvable 6×6 boards (near-minimal, est ~7 min). The only
caveat to weigh for product feel: Deep (and even Quick, here) are fairly sparse
(many blanks) because difficulty is now complexity-driven, not blank-count-driven;
if you want "Quick" to also *look* quick (fewer blanks), that's a separate carve
tweak (return the first in-band state instead of the deepest), not a model change.
