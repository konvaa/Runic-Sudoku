# Phase 3.66.3 — Daily Puzzle Dedicated Save Slot

Fixes the pre-existing quirk flagged in `PHASE_3.66.2_NOTES.md` §7: the daily
puzzle and the campaign level that share a level id (`rs_NNN`) also shared a save
slot, so their in-progress snapshots could overwrite each other.

## The fix

Save slots are now **mode-aware**, not derived purely from the level id:

| mode | save key |
|---|---|
| campaign | `runic_sudoku/rs_NNN` (unchanged) |
| daily | `runic_sudoku/active_daily` (new) |
| freePlay | `runic_sudoku/active_freeplay` (3.66.2) |

A single helper, `saveKeyFor(PuzzleMode, levelId)`, is the one place this mapping
lives. `RunicSudokuSnapshot.saveKey` and `RunicSudokuController.loadOrCreate` both
use it, so reads and writes always agree.

### Shared-slot identity guard

Daily and Free Play each use ONE slot, so a saved snapshot there might belong to
a *different* puzzle than the one being opened (e.g. yesterday's unfinished
daily). `loadOrCreate` now only resumes a snapshot when its `given_cells` match
the requested puzzle; otherwise it starts fresh and overwrites the stale slot.
This means opening today's daily never resumes a previous day's puzzle, while a
same-day interrupted daily still resumes correctly. (Campaign is unaffected: its
per-level key always matches.)

### Completion cleanup

Completing a daily deletes `active_daily` (mirroring Free Play deleting
`active_freeplay`), so a finished daily is not offered for resume.

## Files changed

- `runic_sudoku_snapshot.dart` — `saveKeyFor(...)`; `saveKey` uses it.
- `runic_sudoku_controller.dart` — `loadOrCreate` computes the key via
  `saveKeyFor`, plus the givens-match guard (`_sameGrid`).
- `runic_sudoku_screen.dart` — daily gets a `puzzleId`; deletes `active_daily` on
  daily completion; Free Play delete now also goes through `saveKeyFor`.
- `test/daily_persistence_test.dart` — new.

## Tests

`daily_persistence_test.dart`: `saveKeyFor` mapping; daily saves to
`active_daily` (not `rs_NNN`); a campaign level with the same id is untouched by
daily save ops; the daily slot is cleared on completion; opening today's daily
does not resume a different day's session.

Existing tests pass unchanged: campaign keys/flow are identical to before (mode
defaults to `campaign`), and `daily_puzzle_test` only covers pure selection
logic.

## Decisions / scope

- **Campaign keys deliberately unchanged.** Per-level `rs_NNN` slots are correct
  (any campaign level is independently resumable); only daily needed isolating.
- **No migration.** Old `rs_NNN` snapshots written by a previous daily play are
  simply ignored by the new daily slot; the identity guard prevents a stale
  campaign-keyed snapshot from being misread, and nothing deletes legacy data.

## Build/test status

Sandbox has **no Dart/Flutter SDK** — `flutter test` / `flutter analyze` were not
run here. Changes are additive with backward-compatible defaults; please run both
locally.
