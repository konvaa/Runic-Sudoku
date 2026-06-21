# Phase 3.66 — Free Play Mode

On-demand puzzle generation that reuses the existing `PuzzleGenerator`. No new
content, no new progression. Unlocks after the Quick Runes chapter; pick a
difficulty, a puzzle is generated off the UI thread behind a loading overlay, and
a "Next Trial" loop lets the player keep going.

## 1. Architectural plan

- **Generator stays the single source of puzzles.** Free Play turns on an extra
  acceptance pass (`FreePlayGuardrails`) via a new `freePlay` flag on
  `PuzzleGenerator.generate`. The flag defaults to `false`, so the pre-generated
  campaign pool and `tool/generate_level_pool.dart` are untouched.
- **Generation runs in a background isolate** (`compute`) so even the slow Deep
  case never janks the UI thread; a dark overlay shows while it runs.
- **Free Play is isolated from campaign + daily.** It records only Free Play
  stats on the profile and never writes `completed_level_ids`, the campaign
  count, or the daily streak. It does advance the shared interstitial cadence so
  ads fire at the same every-3rd-completion rate (existing `MonetizationPolicy`,
  unchanged).
- **Unlock is derived, not stored** (see decisions).
- **The play screen is reused.** `RunicSudokuScreen` gained a Free Play mode
  (`isFreePlay`, `freePlayLabel`, `generateNext`) that swaps the active puzzle in
  place for "Next Trial" rather than growing the navigation stack.

## 2. New / modified files

New:
- `lib/games/runic_sudoku/generator/free_play_guardrails.dart` — pure guardrail
  checks (empty rows/cols/boxes, naked-single-from-start).
- `lib/games/runic_sudoku/preparing_overlay.dart` — shared dark "Preparing your
  trial…" overlay (spinner, no progress bar).
- `lib/app/free_play_screen.dart` — `FreeDifficultySelectScreen` + the off-thread
  generation helpers (`generateFreePlayPuzzle`, isolate entry).
- `test/free_play_guardrails_test.dart`, `test/free_play_test.dart`.
- `docs/PHASE_3.66_NOTES.md` (this file).

Modified:
- `generator/puzzle_generator.dart` — `freePlay` flag; carve records the deepest
  in-band puzzle that ALSO passes guardrails.
- `core/profile/player_profile.dart` — `freePlaysCompleted`,
  `freePlaysBestTimes`, `freePlaysCurrentStreak` (+ JSON).
- `core/profile/app_controller.dart` — `onFreePlayCompleted`,
  `resetFreePlayStreak`, stat getters.
- `games/runic_sudoku/progression.dart` — `isFreePlayUnlocked`.
- `games/runic_sudoku/progression_controller.dart` — `freePlayUnlocked` getter.
- `games/runic_sudoku/runic_sudoku_controller.dart` — `fresh` flag on
  `loadOrCreate` (Free Play never resumes a previous puzzle).
- `games/runic_sudoku/runic_sudoku_screen.dart` — Free Play mode + Next Trial.
- `app/app.dart` — `freePlayScreen` builder + `/freeplay` route.
- `app/routes.dart`, `app/main_menu_screen.dart` — Free Play entry (locked until
  unlocked).
- `tool/generator_audit.dart` — `freeplay` arg to audit guardrail generation.

## 3. Guardrails (Free Play only)

- **Quick / Normal:** no fully-empty row or column.
- **Tricky / Deep:** at most one empty row OR column in total, and no fully-empty
  2×3 box.
- **All labels:** at least one naked single available from the start (applied to
  every label — see ambiguities — so the board never opens with nowhere to
  begin).

They are enforced inside the carve: a removal is only recorded as the new best
when the resulting board is in-band AND passes the guardrails, so the generator
keeps the deepest acceptable puzzle on each grid instead of discarding whole
attempts. That keeps rejection rates low.

## 4. Tests

- `free_play_guardrails_test.dart`: constructed-grid unit tests for each rule
  (empty row/col rejection, the one-empty-line allowance for hard labels, empty
  box rejection, a deadly-rectangle board with no naked single), plus real
  generation that asserts every produced puzzle satisfies the guardrails
  (Quick/Normal/Tricky ×4, Deep ×2).
- `free_play_test.dart`: unlock derivation (locked < threshold, unlocked at
  threshold, daily never counts), and stats (count increment, per-difficulty best
  time that only improves, isolation from campaign/daily, interstitial cadence
  fed, streak reset, JSON round-trip).
- Existing tests are unchanged and unaffected (all new fields/params are additive
  with defaults; `widget_test` still finds Daily/Rune Trials/Settings).

> Could not run `flutter test` here — the sandbox has no Dart SDK. Logic that is
> language-independent (guardrails, generation feasibility) was cross-checked with
> the validated Python port (see §7).

## 5. Implementation decisions I made

- **`freePlayUnlocked` is derived, not persisted.** `ProgressionController
  .freePlayUnlocked = Progression.isFreePlayUnlocked(completedLevelIds)`. The
  completed set is already the single source of truth for all unlock state; a
  persisted bool would be a second copy that can drift (the same reason the Phase
  3.5 unlocked sets are recomputed). No new profile flag was added.
- **Naked-single guardrail applies to all four labels**, not just Tricky/Deep, so
  every Free Play board has an obvious first move (the test list asks for "every
  puzzle"). It's effectively free for the dense Quick/Normal boards.
- **One save slot per difficulty** (`freeplay_<label>`), loaded with `fresh:true`.
  Free Play puzzles are ephemeral; this avoids both stale-resume bugs and an
  ever-growing pile of save keys.
- **Next Trial regenerates in place** (swap `_activePuzzle`, reload) instead of
  `pushReplacement`, keeping the nav stack flat: menu → difficulty select → one
  play screen. "Continue" pops to the main menu; generation failure on Next Trial
  pops back to difficulty select. Both reset the streak.
- **Streak = consecutive solves without leaving.** Reset on entering the
  difficulty select (new session), on "Continue", and on generation failure;
  incremented on each solve.
- **Free Play runs the same monetization block** (interstitial + remove-ads
  offer) as campaign, gated by the unchanged `MonetizationPolicy`.

## 6. Not implemented / deferred

- No Free Play resume across an OS app-kill (puzzles are ephemeral by design).
- No Free Play leaderboards / sharing / server data (explicitly out of scope).
- No per-difficulty "plays completed" breakdown UI; stats are stored but only the
  current streak + best time for the active difficulty are surfaced (win dialog).
- No background pre-generation/caching of the next Deep puzzle (see §7).

## 7. Specification ambiguities & the Deep timing risk

- **Naked-single scope.** The guardrails section listed the naked-single rule
  under Tricky/Deep, but the test list says "every puzzle." I applied it to all
  labels (resolved as above).
- **Deep on-demand cost with guardrails — please verify on device.** The Phase
  3.65 audit (no guardrails) put Deep at P95 ≈ 0.31 s / max 0.75 s on PC. The new
  hard-label guardrails (no empty box, ≤1 empty line on near-minimal ~9-clue
  boards) reject a lot more, so Deep needs materially more attempts. The Python
  port (identical algorithm) measured ~5–6× more attempts for Deep (sample
  52–349 vs ~32). On PC that likely lands around ~1–2 s P95, but on a low-end
  Android it could be several seconds — close to or past the 5 s target on the
  tail. Quick/Normal/Tricky are unaffected (≤4 attempts).

  Mitigations already in place: generation is off-thread with an overlay, and
  Free Play Deep gets `maxAttempts = 1200`.

  **Recommendation:** run `dart run tool/generator_audit.dart freeplay` to get the
  real Dart Deep P95/P99/max with guardrails. If Deep's tail is too slow on
  target hardware, cache it like the campaign (pre-generate a small Deep Free Play
  pool and/or generate the next Deep puzzle in the background during play) rather
  than generating purely on demand.
