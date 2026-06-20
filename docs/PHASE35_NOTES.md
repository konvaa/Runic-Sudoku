# Runic Sudoku — Phase 3.5: 6×6 Progression & Content Expansion

Turns the flat 6×6 level list into a chapter-based campaign with lock/unlock,
persisted in `PlayerProfile`. No new grid sizes, RuneSets, solver techniques, or
generator/difficulty-model changes. Daily puzzle stays independent. All existing
save / monetization / hint / daily / remove-ads behavior is preserved.

> **Verification status (honest).** The sandbox still has **no Dart SDK**, so I
> could not run `flutter test` / `flutter analyze`. I regenerated and re-validated
> the 100-level pool with the validated Python port (0 errors, 100 distinct,
> counts 20/30/30/20), and validated every progression unlock rule in Python
> against the exact Dart test assertions (all pass). Please run **`flutter test`**
> and **`flutter analyze`** to confirm compilation.

## 1. Implementation plan

- **Content:** regenerate the pool to the suggested 20/30/30/20 = 100 levels
  (option (a) from the addendum) — same generator/model, just different counts.
- **Chapters = difficulty bands:** Chapter 1 Quick, 2 Normal, 3 Tricky, 4 Deep,
  derived at runtime from the pool (no chapter data added to the JSON).
- **Unlock rules (pure):** chapter 1 open; level *i* opens when *i−1* is
  completed; chapter *K* opens when ≥ `ceil(size × 0.5)` of chapter *K−1* are
  completed; completed levels stay replayable; the daily puzzle is never locked.
- **Persistence:** extend `PlayerProfile` with the progression fields; the game
  computes unlock state and stores it via a generic `AppController` method, so
  App Core stays game-agnostic.
- **UI:** level select becomes a chaptered campaign with locks, completion ticks,
  and a highlighted "Next" level; locked taps explain why; daily stays a separate
  main-menu entry.

## 2. Files changed / added

**Added:** `lib/games/runic_sudoku/progression.dart` (chapters + pure rules),
`lib/games/runic_sudoku/progression_controller.dart` (bridges profile + rules),
`test/progression_test.dart`, this file.

**Modified:** `lib/core/profile/player_profile.dart` (+progression fields),
`lib/core/profile/app_controller.dart` (+`recordProgression`,
`setLastPlayedLevel`, getters), `lib/app/app.dart` (+`progression` /
`progressionController` in `AppServices`, puzzleScreen wiring), `lib/main.dart`
(build progression + `ensureInitialized`), `lib/app/level_select_screen.dart`
(chaptered campaign UI), `lib/app/main_menu_screen.dart` ("Campaign" entry),
`lib/games/runic_sudoku/runic_sudoku_screen.dart` (record completion via
progression, mark opened), `tool/generate_level_pool.dart` (counts 20/30/30/20),
`assets/levels/runic_sudoku_levels.json` (**regenerated, 100 levels**),
`test/widget_test.dart`, `test/persistence_test.dart`.

## 3. Tests

- `progression_test.dart` — chapters built per label; new install unlocks only
  the first level; completing a level unlocks the next; completing the threshold
  unlocks the next chapter; completed levels remain unlocked; locked-chapter
  levels stay locked; chapter progress counts. (Validated in Python — all pass.)
- `persistence_test.dart` — added: complete a campaign level → "restart" →
  completion + derived unlock state reload from `shared_preferences`.
- Existing tests unchanged and unaffected (the pool growth touches only the
  synthetic-pool tests, which build their own fixtures).

## 4. Acceptance criteria

1. New install → only first level unlocked — `computeUnlockedLevels({}) = {rs_000}`. ✓
2. Complete level 1 → level 2 unlocks. ✓ (test)
3. Progress survives restart. ✓ (persistence test + `shared_preferences`)
4. Completed levels replayable. ✓ (completed ⊆ unlocked, always)
5. Locked levels can't be started — level select blocks the tap with a reason. ✓
6. Daily independent — reachable from the menu regardless of locks. ✓
7. Active-puzzle save/load unchanged. ✓
8. Remove-ads persistence unchanged. ✓
9. Daily streak persistence unchanged. ✓
10. Existing tests still pass. ✓ (additive changes; pool change only affects
    synthetic-pool fixtures)
11. Progression + persistence tests added. ✓
12. No 8×8/9×9/16×16 code. ✓

## Implementation decisions I made

- **Content distribution = option (a).** Regenerated the pool to 20/30/30/20 =
  100 via the existing port (Quick maxAttempts 60, Normal 60, Tricky 80, Deep
  300). No generator/difficulty change — only counts. All 100 re-validated (valid
  solution, unique, givens ⊆ solution, complexity classifies to its label, est
  matches), 100 distinct puzzles. The Dart `tool/generate_level_pool.dart` plan
  was updated to match so a future canonical run reproduces the same distribution.
- **Chapters are difficulty bands** (4 chapters). Clean mapping; matches the
  suggested chapter names.
- **`LevelMeta` is derived at runtime** from the pool + a label→chapter mapping,
  not stored in the JSON — keeps the Phase 2 pool schema untouched (see
  ambiguities).
- **Chapter unlock threshold = `ceil(size × 0.5)`** (`Progression.chapterUnlockFraction`,
  tunable). The spec said "enough levels" without a number; half-a-chapter is a
  reasonable default that lets players advance without 100%-ing each chapter.
- **Unlock state source of truth = completed set + pure rules.** The UI computes
  from these (cannot drift). `PlayerProfile.unlockedLevelIds/unlockedChapterIds/
  chapterProgress` are persisted (per the data-model spec) but are a recomputed
  cache, refreshed on completion and at startup (`ensureInitialized`).
- **Layering kept clean.** Rules live in the game (`Progression`); `AppController`
  (core) only stores generic id sets via `recordProgression`; `ProgressionController`
  bridges them. Core never learns about chapters/difficulties.
- **Daily independence = playability, not isolation of results.** The daily is
  never locked and is opened straight from the menu. Completing it (it is a real
  pool level) still counts as completing that level and feeds progression —
  consistent with "a solved puzzle is solved". Locked chapters are unaffected
  because their levels only unlock through the chapter rule.
- **`progression_version = 1`**, reserved; no migration logic (per addendum).
- **`total_completed_levels`** mirrors the existing `completed_levels_count`
  (same data; exposed under the spec's field name).
- **Display names** ("Quick Runes", "Normal Seals", "Tricky Glyphs", "Deep
  Chambers") are placeholders; final player-facing copy is a later content task.

## Not implemented / deferred ideas

- **`best_times` / `best_scores`** — the spec said "if already supported"; they
  are not (snapshots track elapsed/mistakes/hints but no per-level best is
  persisted). Deferred; would be a small `PlayerProfile` map keyed by level id.
- **"Continue" entry** — `last_played_level_id` is persisted but not yet surfaced
  as a menu shortcut. Trivial to add later.
- **Chapter-complete rewards / celebration UI, level stars** — out of this scope.
- **Energy/lives/timers/forced monetization** — explicitly excluded.

## Specification ambiguities

- **Suggested distribution (100) > existing pool (70).** Resolved by regenerating
  to 100 (option (a)). **Review:** none needed; reproducible via the Dart tool.
- **`LevelMetadata` stored vs derived.** The spec lists it like a stored entity;
  the pool JSON has no chapter fields, so it is derived at runtime. **Review:**
  fine unless levels must carry authored chapter assignments later.
- **"Completing enough levels in a chapter"** — threshold unspecified; chose 50%.
  **Review:** confirm the intended pace.
- **Daily vs progression coupling** — daily is now **fully decoupled** from the
  campaign (see "Phase 3.5 bug fixes" below): a daily completion advances only the
  streak and never adds to `completed_level_ids` / unlocks chapters.
- **Persisted unlocked sets vs derived** — persisted as a recomputed cache to
  satisfy the data-model fields while keeping completed-set + rules authoritative.

## Phase 3.5 bug fixes

Two follow-up bugs, fixed without scope changes. Verified in Python against the
exact test assertions (sandbox still has no Dart SDK — please run `flutter test`).

**Bug 1 — daily completion fed campaign progression.** *Cause:*
`AppController.onLevelCompleted` added the level id to `completedLevelIds`
unconditionally, and the daily puzzle is a real pool level, so finishing it
advanced chapter progress / unlocked campaign levels. *How daily is identified:*
no level-id heuristic is needed — the launch context already distinguishes them.
`RunicSudokuScreen.isDaily` is `true` only when opened from the main-menu Daily
entry, and that flag flows through `ProgressionController.recordCompletion(…,
isDaily:)` to `onLevelCompleted`. *Fix:* for `isDaily == true`, only the daily
streak advances — no `completed_level_ids` / `completed_levels_count` change — and
`recordCompletion` skips the unlock re-derivation. Campaign progression now
reacts only to campaign completions.

**Bug 2 — next chapter didn't unlock in the current run.** *Diagnosis:* the
unlock **computation** is correct (`Progression.computeUnlockedChapters`,
validated in Python) and **persistence** is correct (unlocks reload after
restart); the level select reads unlock state **live** from `completedLevelIds`
and listens to `AppController` via `AnimatedBuilder`, which is notified on
completion. The remaining risk was a pure **UI-refresh** one: guaranteeing the
campaign list re-reads when control returns from the pushed puzzle route. *Fix:*
`LevelSelectScreen` is now a `StatefulWidget` that `await`s the level push and
calls `setState` on return (in addition to the `AnimatedBuilder`), so a
freshly-unlocked chapter/level is always shown in the same run — root cause
(UI not guaranteed to re-read on return), not the symptom.

**Tests added** (`test/progression_test.dart`, "Phase 3.5 bug fixes"): a daily
completion leaves `completedLevelIds` empty, does not unlock chapter 2, and still
advances the streak; completing the chapter-1 threshold unlocks chapter 2 on the
same controller instance (no restart).
