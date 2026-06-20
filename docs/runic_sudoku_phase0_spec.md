# Runic Sudoku / Rune Grid — Phase 0 Technical Specification

Status: Pre-implementation. This document defines decisions, data models, interfaces, and acceptance criteria for the MVP. It does not introduce new scope beyond what is defined here.

---

## 1. Product Positioning

**Target player**: casual mobile puzzle players who want short, satisfying logic sessions (commute, waiting room, break) rather than long-form deep puzzle sessions.

**Core hook**: a fast fantasy-themed logic puzzle — sudoku-like deduction on a 6×6 rune grid, designed to be finished in one short sitting.

**Why 6×6**:
- Smaller solution space than 9×9 means faster generation, faster solving, and a session length that matches the "quick puzzle" positioning.
- 6×6 with 2×3 boxes gives 6 distinct symbols — enough for meaningful constraint logic without the depth (and grind) of 9×9.
- Trade-off (explicit, not hidden): 6×6 has a hard ceiling on maximum difficulty. The game must never claim to be a substitute for hardcore 9×9 sudoku.

**Target session length** (see Section 3 for formal model):

| Label | Target solve time | Purpose |
|---|---|---|
| Quick / Tutorial | 30s – 2 min | onboarding, fast win, confidence |
| Normal | 1–3 min | main casual loop |
| Tricky | 3–6 min | requires real thought |
| Deep | 5–10 min | challenge mode, not default |

**Difficulty labels**: `Quick`, `Normal`, `Tricky`, `Deep`. Do not use `Easy/Medium/Hard/Extreme` — "Extreme" on a 6×6 grid that solves in under two minutes undermines credibility and invites negative reviews.

**Marketing pitfalls to avoid**:
- Do not call it "sudoku" without qualification in primary store copy — use "rune logic puzzle" / "logic puzzle inspired by sudoku."
- Do not claim "hardcore," "ultimate," or "for sudoku masters."
- Do not promise unlimited depth or infinite difficulty scaling.
- Position explicitly around session length: "a quick puzzle whenever you have a few minutes," not "the deepest puzzle game."

---

## 2. Game Rules

**Grid**: 6×6, divided into six 2×3 boxes (2 rows × 3 columns per box).

**Box layout** (rows 0–5, cols 0–5, 0-indexed):
- Box index = `(row // 2) * 2 + (col // 3)`
- Boxes occupy row-pairs {0–1, 2–3, 4–5} crossed with column-triples {0–2, 3–5}, giving 6 boxes total (3 rows of boxes × 2 columns of boxes).

**Symbols**: 6 runes, internally mapped to integers 1–6 for all rule/solver logic. Visual representation is a presentation-layer concern (see Section 7).

**Constraints** (all must hold for a valid/complete grid):
- Each row contains each value 1–6 exactly once.
- Each column contains each value 1–6 exactly once.
- Each of the six 2×3 boxes contains each value 1–6 exactly once.

**4×4 Tutorial Mode**:
- Separate grid size (4×4, four 2×2 boxes), values 1–4.
- Used only for onboarding/first-run tutorial. Not a parallel permanent game mode with its own level pool, daily puzzles, or difficulty tiers.
- Shares the same rule engine, solver, and data structures as 6×6 — `grid_size` and `box_shape` are parameters, not hardcoded.

**Explicitly out of MVP scope**:
- Elemental twist (rune-element constraints) — deferred to a future update (v1.1+).
- 9×9 mode.
- Any non-standard constraint types (diagonals, killer-cages, thermo, etc.).
- Multiplayer, leaderboards beyond local best-times.
- Any RuneSet beyond the single default set.

---

## 3. Session-Length and Difficulty Model

Difficulty is not derived solely from the number of empty cells. It is derived from a composite scoring model that estimates both raw solve effort and *cognitive* effort.

### 3.1 Formal Definitions

**`forced_moves_count`**
A forced move is a cell that can be filled using only **naked single** or **hidden single** techniques at the point it is filled (i.e., it has exactly one possible candidate, or it is the only cell in its row/column/box that can hold a given value). Forced moves require no branching or comparison across multiple cells — they are "obvious" once the player scans correctly.

**`decision_points_count`**
A decision point is a solver step where naked/hidden single techniques are insufficient, **and** the human-like solver (using only its MVP technique set — see Section 4.2) can still make progress via one of:
- A supported technique beyond naked/hidden single (MVP: none beyond candidate generation; this becomes relevant once future techniques like pointing pairs are added), **or**
- The current grid state has **more than N cells with ≥2 candidates** (N is a tunable constant, MVP default: `N = 3`) and a naked/hidden single is *not yet available but becomes available after re-scanning candidates following a prior placement* — i.e., the player must actively track multiple cells across several placements before the next "obvious" cell appears.

`decision_points_count` is the primary difficulty signal for puzzles the solver can fully resolve. Two puzzles with identical empty-cell counts can have very different `decision_points_count`.

**Important distinction — solver capability vs. puzzle difficulty**: if the human-like solver, using only MVP techniques (naked/hidden single + candidate generation), **cannot fully solve** a puzzle, this is **not** automatically treated as a higher difficulty. It means the puzzle requires a technique the MVP solver doesn't support. Such a puzzle must be flagged `unsupported_technique = true` by the generator and rejected for the MVP level pool (or set aside as a candidate for a future difficulty tier once the solver's technique set is extended). A puzzle's difficulty label is only assigned if the solver fully resolves it using MVP techniques — never as a fallback label for "solver got stuck."

For MVP, this means generated puzzles should be solvable end-to-end via naked/hidden singles, with `decision_points_count` and `estimated_solve_time` distinguishing easy "obvious scan" puzzles from puzzles requiring the player to track several cells across multiple placements before the next obvious move appears — not puzzles that are "hard" merely because the solver is limited.

**`candidate_complexity`**
A normalized score (0.0–1.0) representing average candidate-set size across all empty cells at the start of the puzzle, weighted toward cells with 3+ candidates:

```
candidate_complexity = (sum over empty cells of max(0, candidates(cell) - 2)) / (empty_cell_count * (grid_size - 2))
```

For 6×6 (`grid_size = 6`), this normalizes against a max candidate count of 4 extra candidates beyond the "trivial" 1–2 range.

**`estimated_solve_time`**
A heuristic estimate, **not** a measured value, computed as:

```
estimated_solve_time =
    (forced_moves_count * T_forced) +
    (decision_points_count * T_decision) +
    (candidate_complexity * T_complexity_modifier)
```

MVP starting constants (seconds):
- `T_forced = 3` (time to scan and place an obvious cell)
- `T_decision = 12` (time to evaluate and resolve a decision point)
- `T_complexity_modifier = 30` (scaling factor applied to the 0–1 complexity score)

These constants are **placeholders**. They are not derived from data — they are a starting heuristic only. See Section 3.3 for the calibration plan.

**Triviality penalty / rejection rules**
A puzzle is rejected by the generator (see Section 5) if:
- `unsupported_technique == true` (the human-like solver could not fully resolve the puzzle using MVP techniques — see above), **or**
- `decision_points_count == 0` for any difficulty label other than `Quick`, **or**
- `estimated_solve_time` falls below the minimum bound of the target label by more than 20%, **or**
- The puzzle is solvable entirely via forced moves from the initial state (a "free" puzzle).

### 3.2 Label Mapping

| Label | `estimated_solve_time` range | Typical `decision_points_count` |
|---|---|---|
| Quick | 30s – 120s | 0 |
| Normal | 60s – 180s | 1–2 |
| Tricky | 180s – 360s | 2–4 |
| Deep | 300s – 600s | 4+ |

Ranges overlap intentionally — `decision_points_count` is the primary classifier; `estimated_solve_time` is a secondary check and rejection filter.

### 3.3 Calibration Plan (Future Phase)

The constants in `estimated_solve_time` are heuristic for MVP. The snapshot save schema (Section 6.3) records `started_at`, `elapsed_time`, and `actual_solve_time` for every completed puzzle. Once a sufficient sample of real player completions exists, `T_forced`, `T_decision`, and `T_complexity_modifier` should be re-fit (e.g., via linear regression against `actual_solve_time`) and the label boundaries in Section 3.2 re-validated. This is explicitly a **Phase 2+/post-launch** activity, not part of MVP delivery. MVP ships with the heuristic as-is.

---

## 4. Solver Architecture

Two separate solvers. They are not merged, do not share a code path beyond basic grid utilities, and serve different purposes.

### 4.1 Fast Uniqueness Solver

**Purpose**: generation-time validation only. Called potentially thousands of times per generated puzzle.

**Method**: constraint propagation (eliminate candidates via row/column/box constraints) + backtracking search.

**Parameters**: `max_solutions = 2`. The search terminates immediately upon finding a second solution.

**Output**: integer — `0`, `1`, or `2` (where `2` means "2 or more").

**Explicit non-goals**: this solver does not log technique usage, does not compute difficulty, and does not need to be "human-like." It should be optimized purely for speed.

### 4.2 Human-Like Difficulty Solver

**Purpose**: post-generation difficulty scoring. Called once per accepted puzzle.

**Method**: simulates solving by repeatedly performing candidate generation, then applying solving techniques in priority order at each step.

**Candidate generation** (not a solving technique — performed continuously as the grid state changes):
- For each empty cell, remove from its candidate set any value already present in the same row, column, or box.

MVP solving techniques (in application order, applied after candidate generation):
1. Naked single
2. Hidden single

Future (not required for MVP, but the solver's step-log structure and the `unsupported_technique` flag mechanism should not preclude adding these later):
- Pointing pairs
- Box/line reduction

**Output**:
- `difficulty_score`: composite numeric score (weighted sum as described in Section 3.1)
- `decision_points_count`
- `forced_moves_count`
- `candidate_complexity`
- `estimated_solve_time`
- `unsupported_technique`: bool — `true` if the puzzle could not be fully resolved using MVP techniques (see Section 3.1)
- `solver_steps_log`: ordered list of `{cell, technique, value}` for each step taken — used for debugging and for the future hint system (a hint can be generated by replaying the next unsolved step from this log)

**Explicit non-goal**: this solver does not need to be fast. It runs once per puzzle at generation time (or at most once per puzzle, cached in the level data).

### 4.3 Why Two Solvers

A single solver optimized for both speed and human-likeness will be either too slow for generation (thousands of calls) or too crude for difficulty scoring. Keeping them separate also means the human-like solver's technique set can be extended later (Section 4.2 "Future") without touching generation performance at all.

---

## 5. Generator Architecture

Pipeline, executed per puzzle:

1. **Full grid generation**: produce a complete, valid 6×6 grid (all constraints satisfied) via randomized backtracking fill.
2. **Cell removal**: iterate over cells in randomized order. For each cell, tentatively remove its value, then run the Fast Uniqueness Solver (Section 4.1) on the resulting partial grid.
   - If result `== 1`: keep the cell removed, continue.
   - If result `>= 2`: restore the cell's value, mark this cell as "not removable this pass," continue to next cell.
3. **Stop condition**: continue removal until either (a) no further cell can be removed without breaking uniqueness, or (b) a target empty-cell count (informed by target difficulty label) is reached.
4. **Scoring**: run the Human-Like Difficulty Solver (Section 4.2) on the resulting puzzle. Obtain `difficulty_score`, `decision_points_count`, `estimated_solve_time`, etc.
5. **Acceptance check**: apply the triviality penalty rules (Section 3.1). If the puzzle is rejected:
   - Either restart from step 1 with a new seed, or
   - Attempt a different removal order from the same full grid (cheaper — full grid generation is more expensive than re-running removal).
6. **Seed storage**: store the random seed used for full-grid generation plus the removal order (or the resulting `given_cells` set directly — see Section 6.3). Storing `given_cells` + `solution_grid` directly is sufficient for reproducibility; the seed is supplementary/debug information.
7. **Export/import**: a level is fully defined by `{grid_size, box_shape, solution_grid, given_cells, difficulty_label}`. This structure must be serializable to/from JSON for level packs, daily puzzles, and debugging.

**Explicit non-goal for MVP**: no elemental constraints, no multi-region puzzles, no irregular box shapes.

---

## 6. Save Architecture

### 6.1 Decision: Complete Snapshot, Not Delta

Every `save()` call writes the **entire current state** of the active level. No delta/incremental saves. This is a deliberate simplicity choice: crash recovery must restore the exact board state (grid, notes, mistakes, timer) without replaying a history of moves.

### 6.2 Save Interface

```
save(snapshot, trigger_type)
```

**`trigger_type` enum** (MVP set):
- `level_start`
- `placement_complete`
- `notes_changed`
- `hint_used`
- `mistake_checked`
- `level_complete`
- `app_pause`
- `rewarded_ad_completed`
- `interstitial_shown`
- `purchase_completed`

Not all triggers are relevant to Runic Sudoku's gameplay loop, but the enum is shared across the App Core (see Section 7) and must remain a superset usable by future realtime modules (see Section 8).

### 6.3 Snapshot Schema (Runic Sudoku)

```json
{
  "game_id": "string",
  "level_id": "string",
  "seed": "string",
  "grid_size": 6,
  "box_shape": "2x3",
  "solution_grid": "int[6][6]",
  "given_cells": "bool[6][6]",
  "current_grid": "int[6][6]",
  "notes_grid": "int[][6][6]",
  "mistakes_count": "int",
  "hints_used": "int",
  "started_at": "timestamp",
  "elapsed_time": "seconds (float)",
  "last_saved_at": "timestamp",
  "completed": "bool",
  "difficulty_label": "string (Quick|Normal|Tricky|Deep)",
  "estimated_solve_time": "seconds (float, from generator)",
  "actual_solve_time": "seconds (float, null until completed)"
}
```

Notes:
- `notes_grid` is a per-cell list of candidate annotations (0–6 entries per cell), independent of `current_grid`.
- `actual_solve_time` is set only on `level_complete` and equals `elapsed_time` at that point. This field, paired with `estimated_solve_time` and `difficulty_label`, is the dataset for the future calibration pass (Section 3.3).
- A save is written on every trigger relevant to Sudoku: `level_start`, `placement_complete`, `notes_changed`, `hint_used`, `mistake_checked`, `level_complete`, `app_pause`. Ad/purchase triggers update the App Core profile snapshot (Section 7), not the level snapshot, but both are part of the same `save()` call contract.

### 6.4 Crash Recovery

Because every save is a full snapshot, recovery on app relaunch is: load the most recent snapshot for the active `level_id`, restore `current_grid`, `notes_grid`, `mistakes_count`, `hints_used`, and resume the timer from `elapsed_time`. No move history replay is needed or stored.

---

## 7. App Core / Grid Core / Game Module Architecture

### App Core (shared across all future games)
- Menu
- Settings
- Save system (the `save(snapshot, trigger_type)` contract and persistence layer)
- Ads (rewarded + interstitial wrappers)
- Purchases (remove-ads, future IAP)
- Analytics (event logging, lifetime counters)
- Level select
- Daily challenge shell (scheduling/unlock logic; content is game-specific)
- Theme manager (loads `Theme` + `RuneSet` records — see Section 9)

### Grid Core (shared across grid-based games)
- Coordinates (row/col addressing, generic to any `grid_size`)
- Cells (generic cell state container)
- Grid dimensions (`grid_size`, `box_shape` as configurable parameters, not constants)
- Layers (support for multiple overlapping data layers per cell — e.g., value layer + notes layer for Sudoku; positions/tokens layer for other games)
- Input mapping (abstract tap/drag/swipe → grid coordinate translation)
- Grid renderer (generic grid drawing, themed via Theme/RuneSet)

### Runic Sudoku Module (game-specific)
- Sudoku rules (row/column/box constraint validation, parameterized by `grid_size`/`box_shape`)
- Candidates/notes management
- Fast Uniqueness Solver
- Human-Like Difficulty Solver
- Generator
- Validation (real-time move validation against `solution_grid`/constraints)
- Difficulty scoring (wraps the human-like solver output into `difficulty_label`)

**Boundary rule**: anything that assumes "this is a sudoku" lives in the Runic Sudoku Module. Grid Core must remain agnostic to what values mean or what constraints apply — it only knows about coordinates, layers, and rendering.

---

## 8. Realtime Compatibility Risk Check

This section is risk-mitigation, not Sudoku specification. Its purpose: confirm that `save(snapshot, trigger_type)` and App Core do not implicitly assume a turn-based puzzle model, before any realtime game (e.g., Shadow Maze) is built on top of the same core.

### 8.1 Additional Trigger Types for Realtime

The `trigger_type` enum (Section 6.2) must be extensible to include, at minimum:
- `periodic_tick` — periodic autosave during active realtime play (e.g., every N seconds)
- `death`
- `revive_used`

These are not used by Runic Sudoku but must not require restructuring the save contract when added.

### 8.2 Example: Shadow Maze Snapshot (illustrative only, not implemented)

For a realtime arcade game, a snapshot written on `periodic_tick`, `death`, or `app_pause` would contain:

```json
{
  "game_id": "shadow_maze",
  "level_id": "string",
  "player_position": {"x": 0.0, "y": 0.0},
  "enemy_positions": [{"id": "string", "x": 0.0, "y": 0.0}],
  "pickups_remaining": ["id", "..."],
  "score": "int",
  "remaining_lives": "int",
  "run_timer": "seconds (float)",
  "current_level": "string",
  "active_effects": [{"effect_id": "string", "remaining_duration": "seconds"}]
}
```

### 8.3 Conclusion of Risk Check

The `save(snapshot, trigger_type)` contract is shape-agnostic: `snapshot` is an opaque payload per game module, and `trigger_type` is the only shared vocabulary. As long as the trigger enum includes tick-based and event-based triggers (Section 8.1), the App Core save system does not need to know whether a game is turn-based or realtime. **No changes to the App Core save contract are required to support a future realtime module.** This check is satisfied by the design in Section 6 as written — no rework needed.

---

## 9. Theme and RuneSet Data Model

Theming is data, not just a palette swap. Both `Theme` and `RuneSet` are stored as structured records, even though MVP ships with exactly one of each.

### Theme

```json
{
  "id": "string",
  "name": "string",
  "background": "asset reference",
  "board_style": "asset/style reference",
  "cell_style": "asset/style reference",
  "rune_set_id": "string (references RuneSet.id)",
  "sound_pack_id": "string",
  "particle_style": "asset/style reference"
}
```

### RuneSet

```json
{
  "id": "string",
  "symbol_1": "asset reference",
  "symbol_2": "asset reference",
  "symbol_3": "asset reference",
  "symbol_4": "asset reference",
  "symbol_5": "asset reference",
  "symbol_6": "asset reference",
  "display_names": ["string x6"],
  "accessibility_labels": ["string x6"]
}
```

**MVP scope**: exactly one `Theme` record and one `RuneSet` record, both hardcoded as default/seed data. The data model must support additional records being added later without schema changes — this is a data-population task for future content updates, not a code change.

**Separation principle**: `Theme` controls presentation (visuals/audio). `RuneSet` controls the symbol vocabulary (which is referenced by `rune_set_id` from a `Theme`, but is itself independent of any single theme). This separation is what allows future content (e.g., a "Moon Runes" RuneSet paired with a "Shadow Temple" Theme) without touching the Sudoku rule engine, which only ever operates on integers 1–6.

---

## 10. Monetization Model

### MVP Monetization Elements
- **Rewarded hint**: watch a rewarded ad to reveal one correct cell (uses `solver_steps_log` from Section 4.2 to determine which cell to reveal).
- **Mistake check**: 1 free check per puzzle, then rewarded-ad-gated for additional checks within the same puzzle. This is a final decision for MVP — less aggressive than gating the first check behind an ad, while still providing a monetization touchpoint. `mistakes_count` and free-check usage are tracked per level snapshot.
- **Interstitial**: shown only between levels (after `level_complete`), never during active puzzle solving. Frequency capped (see remove-ads trigger logic below).
- **Remove ads**: one-time purchase, removes interstitials permanently. Rewarded ads remain available post-purchase as optional player-initiated bonuses (hints, etc.) — these are opt-in and not removed by the purchase.

### Remove-Ads Offer Trigger Logic
- Do **not** show the remove-ads offer on first app open.
- First offer: after the player completes a small number of levels OR has played for a minimum session duration (exact thresholds are tuning parameters, not architectural — e.g., "after level 5" is a reasonable starting default).
- Re-offer: after 2–3 interstitials have been shown since the last offer (or since install, for the first re-offer).
- Always accessible manually via Settings/Store regardless of the above triggers.

### Required Save/Analytics Fields (App Core profile, separate from per-level snapshot)

```json
{
  "sessions_count": "int",
  "completed_levels_count": "int",
  "interstitial_shown_lifetime": "int",
  "rewarded_shown_lifetime": "int",
  "remove_ads_offer_shown_count": "int",
  "remove_ads_purchased": "bool",
  "first_open_timestamp": "timestamp",
  "last_played_date": "date",
  "daily_streak": "int"
}
```

These fields live in the App Core profile/save data (distinct from the per-level snapshot in Section 6.3) and are updated via the same `save(snapshot, trigger_type)` contract using triggers such as `interstitial_shown`, `rewarded_ad_completed`, and `purchase_completed`.

---

## 11. ASO Pre-Research Checklist

Before designing store assets (icon, screenshots, copy), analyze 10 competing puzzle games. For each, record:

| Field | Notes |
|---|---|
| Game name | |
| Icon | screenshot/reference |
| First 3 screenshots | screenshot/reference |
| Primary keywords | from title + description |
| Review count | |
| Rating | |
| Last update date | |
| Update frequency / changelog pattern | how often new content/levels ship |
| App size (MB) | important for a "small puzzle" positioning — flag any competitor with bloated size as a contrast point |
| Monetization model | ad types, IAP, remove-ads pricing |
| Daily puzzle (yes/no) | |
| Offline play (yes/no) | |
| Most common complaints in reviews | e.g., too many ads, too easy, repetitive levels, poor hints, confusing UI |
| Visual differentiation | what makes it look distinct (or generic) |

This research informs (but is not part of) the eventual: name, icon, screenshot set, short description, and hook line. Those deliverables are out of scope for this document.

---

## 12. Acceptance Criteria

Acceptance criteria are split by phase. Each phase has its own checkpoint — Phase 2 should not begin until Phase 1 criteria are met, and Phase 3 should not begin until Phase 2 criteria are met.

### Phase 1 — UI Prototype (no generator, manually-authored puzzle)

- [ ] A manually-entered 6×6 puzzle (hardcoded `solution_grid` + `given_cells`) renders correctly on screen, including 2×3 box boundaries.
- [ ] Player can select a cell and input a rune (1–6 equivalent).
- [ ] Row/column/box constraint validation works (incorrect placements are detected against `solution_grid` or live constraint check).
- [ ] Notes/candidates mode works (player can mark candidate values per cell, independent of the main value).
- [ ] `save(snapshot, trigger_type)` persists the full snapshot on `placement_complete`, `notes_changed`, and `app_pause`.
- [ ] Save/load restores a partially-completed level exactly as left (grid, notes, mistakes count, elapsed time).
- [ ] Win condition triggers correctly when `current_grid == solution_grid`.
- [ ] `app_pause` reliably writes a snapshot (verified via force-close and relaunch).
- [ ] **Preliminary ASO visual check completed**: a first-pass review of the ASO competitor research (Section 11, at least icon/screenshot/visual-style columns) is done before any final UI/theme polish begins, so the visual direction can be adjusted while changes are still cheap — full ASO asset production remains a Phase 3 deliverable.

### Phase 2 — Generator

- [ ] Full-grid generator produces a valid 6×6 grid satisfying all row/column/box constraints (verified by unit tests, Section 12.1).
- [ ] Cell removal preserves solution uniqueness at every step (Fast Uniqueness Solver confirms `result == 1` after each accepted removal).
- [ ] Fast Uniqueness Solver correctly returns `0`, `1`, or `2` for test fixtures (broken, unique, ambiguous puzzles respectively).
- [ ] Human-Like Difficulty Solver returns `difficulty_score`, `decision_points_count`, `forced_moves_count`, `candidate_complexity`, `estimated_solve_time`, and `solver_steps_log` for any valid puzzle.
- [ ] Generator rejects puzzles failing the triviality penalty rules (Section 3.1) and retries.
- [ ] A level can be fully reproduced from stored level data: `solution_grid` + `given_cells` + metadata (`difficulty_label`, `estimated_solve_time`, etc.) is canonical and sufficient to recreate the exact level. The `seed` field is stored for debugging/traceability only and is not relied upon as the source of truth — generator changes must not invalidate previously stored levels.

### Phase 3 — Product MVP

- [ ] Level select screen lists levels with difficulty labels (`Quick`/`Normal`/`Tricky`/`Deep`).
- [ ] Daily puzzle is available and resets on schedule.
- [ ] Rewarded hint flow works end-to-end (ad → reveal cell from `solver_steps_log`).
- [ ] Remove-ads purchase flow works and persists `remove_ads_purchased = true`.
- [ ] Settings screen accessible, includes manual remove-ads entry point.
- [ ] Basic analytics events fire for all required fields in Section 10 (sessions, completions, ad shows, etc.).
- [ ] ASO asset package (icon, 3 screenshots, short description, hook line) completed based on Section 11 research — informed by, not blocked on, the research table itself.
- [ ] No interstitial ad is shown while a puzzle is in an active (incomplete, in-progress) state — only between levels.
- [ ] Core gameplay (solving puzzles, including pre-downloaded/bundled levels) works fully offline; only ads and purchases require connectivity.

### 12.1 Minimum Unit Test Set (referenced from Phase 2)

- Every row of a complete grid contains values 1–6 exactly once.
- Every column of a complete grid contains values 1–6 exactly once.
- Every 2×3 box of a complete grid contains values 1–6 exactly once.
- Coordinate-to-box-index mapping is correct for all 36 cells (per the formula in Section 2).
- A valid complete grid passes full validation.
- An invalid grid (e.g., duplicate in a row) fails validation.
- A puzzle with a known unique solution returns `1` from the Fast Uniqueness Solver.
- A puzzle constructed to have two valid solutions returns `2`.
- A puzzle with an unsolvable/contradictory state returns `0`.

---

*End of Phase 0 specification. No scope beyond the items above is included. The exact remove-ads offer thresholds (Section 10) remain a tuning/implementation choice, not an architectural blocker, and can be resolved during implementation without requiring a new specification round.*
