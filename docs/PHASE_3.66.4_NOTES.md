# Phase 3.66.4 — Free Play resume banner shows on every return

## Bug

The "Continue your trial?" banner only appeared after a force-stop, not after a
normal return to the menu.

## Actual cause

Not a deletion-on-pop bug — verified that nothing deletes the slot on
`Navigator.pop()` or `app_pause`; the slot is removed only on completion
(`level_complete`) and on "New Trial". The real cause: the back button pops the
play screen back onto the **already-mounted** `FreeDifficultySelectScreen`, whose
`_checkResumable()` had only run once in `initState` (before any session existed).
After a force-stop the screen is recreated, so `initState` re-checked and the
banner showed — hence "only after force-stop".

## Fix

- `_checkResumable()` now runs on `initState` **and** after returning from every
  play-screen push (`_start`, `_startDeep`, `_continueResume`). The banner appears
  whenever an unfinished snapshot exists, regardless of how the previous session
  was left.
- `_checkResumable()` also clears the banner when the slot is gone or completed
  (so it disappears correctly after completion / New Trial).

Deletion timing is unchanged and already correct: slot deleted only on completion
or "New Trial"; never on back button or `app_pause`.

## Daily

`active_daily` already follows the same rules and needs no change: it is deleted
only on completion, and the daily screen is rebuilt from the menu on every launch
(no cached select screen), so it always loads/resumes from `active_daily`.
Campaign is untouched.

## Tests

Added `free_play_persistence_test.dart` › "leaving without completing
(app_pause) keeps the slot resumable" — asserts `app_pause` does not delete the
slot and it stays resumable (`completed == false`). The banner re-check itself is
UI behaviour (would need a widget test); the underlying persistence rule is
covered.

## Build/test status

No Dart/Flutter SDK in this environment — `flutter test` / `flutter analyze` not
run here. Please run both locally.
