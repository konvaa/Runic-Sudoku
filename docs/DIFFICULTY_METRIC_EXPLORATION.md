# Difficulty-metric exploration (6×6) — diagnostic findings & recommendation

> **STATUS: superseded by the decision.** This was the exploration phase. The
> real measured numbers have since been collected and a model chosen — see
> **"Follow-up #2: complexity-based difficulty model"** in `PHASE2_NOTES.md`.
> Outcome: stall dropped, `candidate_complexity` is the primary signal, three
> levels on 6×6 (Quick/Normal/Tricky), Deep reserved for larger grids. The
> predictions below were directionally confirmed by the real data.

This is a **measurement/diagnostic** write-up, not an implementation decision.
No production code (`HumanLikeSolver`, `DifficultyScorer`, `DifficultyTuning`)
was changed. The experiment lives in `tool/difficulty_metric_exploration.dart`
and uses its own self-contained pure-single probe solver.

> **Honesty note — I could not run the sweep in this environment.** The sandbox
> that executes Dart/Python was unavailable, so I cannot paste real measured
> numbers. The tables below are **analytical predictions** (clearly labelled),
> derived from how the metrics must behave on a 6×6/2×3 grid. **Please run**
> `dart run tool/difficulty_metric_exploration.dart` to get the real numbers; it
> prints exactly the table and the Pearson correlations described here. Where a
> result is a provable fact (not a prediction), it is marked **[CERTAIN]**.

## What the script measures

For blank fraction 0.20 → 0.70 in 0.05 steps, it carves `samples = 100` unique
puzzles (full grid → random removal keeping uniqueness, **before** any rejection
rules) and runs a naked+hidden-only probe (no solution assistance), reporting per
fraction:

- `stall%` — share of puzzles the singles cannot finish (the "true stall rate", Q1);
- `avgSteps` — naked+hidden placements to solve (solving-step-count metric);
- `hiddenRatio` — hidden ÷ (naked+hidden) steps;
- `maxCands` — peak candidate-set size seen at any point while solving;
- `complexity` — Phase 0 `candidate_complexity` of the givens (for reference);
- plus Pearson r of each metric vs blank fraction (Q3).

## Q1 — does a "stall" exist on 6×6? (predicted)

| blank frac | predicted stall% |
|-----------:|-----------------:|
| 0.20–0.45  | ~0% |
| 0.50       | ~0–1% |
| 0.55       | ~0–2% |
| 0.60       | ~1–4% |
| 0.65–0.70  | ~3–10% (and removal often can't even reach these — uniqueness caps actual blanks near ~22–26) |

**Reading:** stalls are essentially absent across the usable range and only flicker
into existence right at the uniqueness limit. This matches the live data you
already captured (decisions = 0 for 99–100/100 even at the Deep fraction). The
conclusion the data points to is the one you suspected: **on a 6-value grid,
naked/hidden singles almost always finish the puzzle**, so "stall / decision
point" is degenerate *by grid size*, not by definition. No amount of redefining
the decision point rescues it; both the "hidden-single-in-complex" and the
"stall + solution-assisted" definitions are rare for the same underlying reason.

## Q2 + Q3 — alternative metrics and their correlation with blank fraction (predicted)

| metric | low frac (0.20) | high frac (0.65) | trend | predicted Pearson r vs frac | carries info beyond "how empty"? |
|---|---|---|---|---|---|
| solving step count | ~7 | ~22 (caps) | rises, then plateaus at the uniqueness limit | ~ +0.97 | **No** — **[CERTAIN]** when solved by singles, `steps == blank count` exactly, so this *is* the blank count |
| hidden-single ratio | low (~0.0–0.1) | higher (~0.2–0.45) | rises | ~ +0.85–0.95 | **Yes** — measures technique mix (scanning load), not just emptiness |
| max candidates / cell | ~2–3 | ~4–5 (caps at 6) | rises, saturates | ~ +0.9 then saturates | Partly — correlated with emptiness but bounded; proxies cognitive load |
| candidate_complexity | low | higher, saturates | rises, saturates | ~ +0.9 | Partly — normalized density; close cousin of max-candidates |

**[CERTAIN] facts**

- `solving step count == number of blanks` whenever the puzzle is solved by
  singles (each step fills exactly one empty cell). So "step count" is a perfect
  but **circular** difficulty signal — it only re-reports the blank count the
  generator already chose. Monotone, but uninformative as a difficulty *discriminator*.

**Why your `avg_est` inverted (Quick highest).** With decisions ≈ 0 and
`candidate_complexity` small, the Phase 0 formula collapses to
`est ≈ forced_moves × T_forced = blanks × T_forced`. Quick removes maximally, so
it has the **most** blanks → the **highest** est. The estimator is therefore
measuring emptiness, not reasoning difficulty — which is backwards. Any future
estimator should down-weight `forced_moves` (≡ blanks) and instead weight the
per-step reasoning signals (hidden-ratio, candidate density).

## Q4 — recommendation (for discussion, not a final decision)

1. **Drop stall / decision-points as the difficulty axis on 6×6.** The probe
   confirms it is ~always 0; it cannot separate levels here. Keep the concept,
   but treat it as a signal that only becomes meaningful on larger grids (9×9),
   where singles genuinely run out.

2. **Base 6×6 difficulty on the two non-degenerate signals**, combined:
   - **candidate density** (`candidate_complexity`, or peak `maxCands`) — how
     many candidates the player must juggle; and
   - **hidden-single ratio** — how much of the solve is scanning a whole
     unit vs reading off a forced cell.
   Both grow with difficulty without being a pure restatement of the blank count,
   and both actually occur on 6×6. A simple weighted blend of these two is the
   most defensible 6×6 difficulty score. (Do **not** make `estimated_solve_time`
   proportional to `forced_moves`.)

3. **The Phase 0 four-level model is probably too granular for 6×6.** Singles
   solve almost everything and the discriminating metrics (complexity,
   hidden-ratio) vary modestly and saturate, so the achievable spread realistically
   supports **2–3 distinguishable levels**, not 4. Suggested options to discuss:
   - collapse 6×6 to **Quick / Normal / Tricky** (3) — or even **Easy / Hard** (2)
     — mapped to bands of the density+hidden-ratio blend; and
   - reserve the full 4-level ladder, and especially **Deep**, for a future 9×9
     where decision points and harder techniques exist. (Deep's 240 s floor was
     already shown to be unreachable on 36 cells regardless of definition.)

4. **Next concrete step:** run the script, paste the real table, and we pick the
   blend + number of levels from the measured numbers. If the real `hiddenRatio`
   spread turns out flat too, the honest conclusion is that 6×6 supports only 2
   levels and difficulty there is essentially "how many blanks", with genuine
   difficulty tiers deferred to larger grids.

## How to run

```
dart run tool/difficulty_metric_exploration.dart
```

It is pure Dart (no Flutter), prints the per-fraction table and the Pearson
correlations, and changes nothing in the app.
