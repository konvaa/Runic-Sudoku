# Phase 3.66.2 — Free Play Session Persistence

Free Play sessions were lost on interruption (force-stop, OS kill, a call mid-
puzzle) because the screen always loaded Free Play `fresh`, ignoring any saved
snapshot. This phase gives Free Play a dedicated, independent save slot and a
resume path — the same durability campaign levels already have.

## 1. Architecture

- **Dedicated Free Play slot:** all Free Play sessions persist under
  `runic_sudoku/active_freeplay` (one in-flight session at a time). It is a
  distinct key from any campaign (`rs_NNN`) or daily slot, so Free Play can never
  overwrite them.
- **The snapshot already carried everything** needed to rebuild and resume a
  puzzle (`solutionGrid`, `givenCells`, `difficultyLabel`, `currentGrid`,
  `notesGrid`, counters, timing). The only change required was to *load* it
  instead of discarding it.
- **Self-describing snapshots:** added `PuzzleMode { campaign, daily, freePlay }`
  + an optional `puzzleId` (content hash of the givens) to the snapshot/state, so
  a persisted session identifies itself. Both default to `campaign`/`null`, so
  every existing save still parses unchanged.
- **Resume on entry:** opening the Free Play screen checks the slot; an
  unfinished session shows a "Continue your [Difficulty] trial? (mm:ss elapsed)"
  banner with **Continue** / **New Trial**.
- **Cleared on completion:** finishing a Free Play puzzle deletes the slot, so a
  solved session is never offered for resume.

## 2. New / modified files

- `runic_sudoku_snapshot.dart` — `PuzzleMode` enum, `mode` + `puzzleId` fields
  (+ JSON, copyWith), `puzzleIdFromGivens` hash. Backward-compatible defaults.
- `runic_sudoku_state.dart` — `mode`/`puzzleId` threaded through
  `fromPuzzle`/`fromSnapshot`/`toSnapshot`.
- `runic_sudoku_controller.dart` — `loadOrCreate` gained `mode`/`puzzleId`
  (alongside the existing `fresh`).
- `runic_sudoku_screen.dart` — `freePlayResume` flag; `_load({resume})` reads the
  slot when resuming (else fresh); sets `mode`/`puzzleId`; deletes the slot on
  Free Play completion.
- `app/free_play_screen.dart` — `freePlaySaveLevelId = 'active_freeplay'`; Free
  Play puzzles use that slot; resume banner (`_ResumeBanner`); Continue / New
  Trial; reconstruct a `ManualPuzzle` from the saved snapshot.
- `app/app.dart` — `freePlayScreen(..., resume)` passthrough.
- `freeplay/deep_pool.dart` — Deep entries build under `active_freeplay`.
- `test/free_play_persistence_test.dart`; `docs/PHASE_3.66.2_NOTES.md`.

## 3. Save / restore flow

New Free Play puzzle → `loadOrCreate(fresh: true, mode: freePlay)` → starts
clean and writes `active_freeplay`. Every standard trigger
(`placement_complete`, `notes_changed`, `hint_used`, `mistake_checked`,
`app_pause`, `level_complete`) saves there via the existing controller. On
re-entry, the select screen loads the slot; **Continue** rebuilds the puzzle from
the snapshot and launches with `freePlayResume: true` →
`loadOrCreate(fresh: false)` → `RunicSudokuState.fromSnapshot`. **New Trial**
deletes the slot and starts a fresh puzzle of the same difficulty. On
`level_complete` the screen deletes the slot; "Next Trial" then writes a new one.

## 4. Tests

`free_play_persistence_test.dart`: saved on placement (with `mode`/`puzzleId`);
restored after a simulated SharedPreferences restart; completion marks solved and
the slot is then cleared; Free Play ops never touch the campaign slot; an
unfinished snapshot is detected for the resume banner; "New Trial" deletes the
session. Existing tests unchanged — `snapshot_serialization_test` checks fields
(not exact maps) and the new fields default cleanly.

## 5. Implementation decisions

- **One Free Play slot, not per-difficulty.** Only one Free Play session is ever
  in flight; a single `active_freeplay` slot keeps it simple and matches the
  "resume the current trial" model.
- **`fresh` vs `resume`:** Free Play normally loads fresh (new puzzle); resume is
  the explicit exception (`freePlayResume`). "Next Trial" always loads fresh.
- **`puzzleId` = content hash of the givens** for all Free Play difficulties
  (spec allows "hash" for Deep too), avoiding threading the bundled id through
  the UI. It is informational; resume keys off the slot, not the id.
- **Delete on completion happens before the win dialog** so an app-kill during
  the dialog can't resurrect a finished puzzle.

## 6. Not implemented / deferred

- No history of finished Free Play snapshots (slot is deleted on completion, per
  spec).
- Resume offers a single session (the latest), not a list.

## 7. Specification ambiguities

- The spec lists three explicit slots (`active_campaign`, `active_daily`,
  `active_freeplay`). The **actual** code keys campaign saves per pool level
  (`runic_sudoku/rs_NNN`); that per-level scheme is correct and unchanged.
- **FIXED in the follow-up (see `PHASE_3.66.3_NOTES.md`):** the daily/campaign
  shared-slot collision noted here. Daily now persists to a dedicated
  `runic_sudoku/active_daily` slot via a mode-aware save key, so it can no longer
  overwrite (or be overwritten by) the campaign level that shares its `rs_NNN`
  id. Campaign keys are untouched.

## 8. Build/test status

Sandbox has **no Dart/Flutter SDK**, so `flutter test` / `flutter analyze` could
not be run here. All changes are additive with backward-compatible defaults;
please run both locally — `free_play_persistence_test.dart` is the key check.
