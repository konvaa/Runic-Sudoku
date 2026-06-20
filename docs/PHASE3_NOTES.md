# Runic Sudoku — Phase 3 (Product MVP) implementation notes

UI + game logic for level select, daily puzzle, rewarded hints, mistake-check
gating, and monetization wiring. Ads/purchases stay on the Phase 1 **no-op**
services (no AdMob/Billing SDK); this phase wires the *logic that calls them*.

> **Verification status (honest).** The sandbox has **no Dart SDK**, so I could
> not run `flutter test` / `flutter analyze`. I did port and run the pure logic
> in Python and confirmed it: daily index is deterministic, uses all 70 pool
> indices across a year with no consecutive repeats; the hint picks the right
> next step (and corrects a wrong cell); interstitials fire on the 3/6 cadence;
> the offer thresholds behave as specified; the daily-streak day arithmetic
> matches. Please run **`flutter pub get`** (new `shared_preferences`
> dependency), then `flutter test` / `flutter analyze`. The persistence path is
> covered by `test/persistence_test.dart` (mock prefs, simulated restart); a true
> force-close/reopen on a device/emulator needs a human (manual scenarios in the
> "Persistence" section).

## 1. Architectural plan

Phase 3 adds an **App-Core profile layer** and **product UI**, reusing Phase 1/2
unchanged underneath:

- **`/core/profile`** — `PlayerProfile` (persisted as a `Snapshot` at
  `app/profile`) and `AppController` (a `ChangeNotifier` owning the profile:
  session, completion, daily streak, monetization counters; persists via the
  existing `SaveService`, logs analytics).
- **`/core/monetization`** — `MonetizationPolicy`: pure, unit-testable decisions
  (`shouldShowInterstitial`, `shouldShowRemoveAdsOffer`) with documented
  thresholds. No UI, no SDK.
- **`/games/runic_sudoku`** — `LevelPool` (loads the Phase 2 asset →
  `ManualPuzzle`s with stable ids, grouped by label, daily selection) and
  `DailyPuzzleSelector` (pure date→index). The controller gained the
  steps-log-driven hint + `checksUsed`.
- **`/app`** — `AppServices` now also carries `appController` + `levelPool`; the
  menu (daily + streak), level select (pool grouped by label + completion), play
  screen (rewarded hint/check + level-complete interstitial/offer), and settings
  (remove-ads persisted to the profile) are wired.

Dependency direction is preserved: app → game → core. The play screen takes the
core services it needs (ads, purchases, app controller) by constructor, so the
game layer never imports the app layer.

## 2. Data models (new / modified)

- **`PlayerProfile`** (new, `Snapshot`): `sessions_count`,
  `completed_levels_count`, `completed_level_ids`, `interstitial_shown_lifetime`,
  `rewarded_shown_lifetime`, `remove_ads_offer_shown_count`,
  `remove_ads_purchased`, `first_open_timestamp`, `last_played_date`,
  `last_daily_completed_date`, `daily_streak`, plus two cadence counters
  (`levels_since_interstitial`, `interstitials_since_last_offer`).
- **`RunicSudokuSnapshot`** (modified): added `checks_used` (free/rewarded
  mistake-check tracking). Optional on read for backward compatibility.
- **`RunicSudokuController`** (modified): `solverSteps` (the logical step log),
  `revealNextHint()`, `checksUsed` / `hasFreeCheck`.
- **`LevelData.estimatedSolveTime`** (added in the Phase 2 follow-up) — carried
  into each pool entry.

## 3 & 4. Code skeleton + tests

New: `core/profile/player_profile.dart`, `core/profile/app_controller.dart`,
`core/monetization/monetization_policy.dart`,
`games/runic_sudoku/level_pool.dart`, `games/runic_sudoku/daily_puzzle.dart`.
Modified: snapshot, state, controller, the four `/app` screens, `app.dart`,
`main.dart`.

Tests (`/test`): `daily_puzzle_test.dart` (determinism, spread, pool parse/by-id/
by-label), `hint_test.dart` (reveals the next step, skips solved cells, corrects
wrong cells, fallback), `mistake_check_test.dart` (free → gated), and
`monetization_test.dart` (interstitial cadence, offer thresholds, daily streak,
completed-id dedupe). `widget_test.dart` updated for the new `AppServices`.

## 5. Acceptance criteria mapping

- Level select lists levels with difficulty labels → `LevelSelectScreen` groups
  `LevelPool` by label with completion state. ✓
- Daily puzzle available + resets on schedule → main-menu Daily entry +
  `DailyPuzzleSelector` (local date). ✓
- Rewarded hint end-to-end (ad → reveal from `solver_steps_log`) → `_onHint` →
  `showRewardedAd` → `revealNextHint`. ✓
- Remove-ads purchase persists `remove_ads_purchased=true` → settings + offer →
  `AppController.setRemoveAdsPurchased`, saved on the profile through the now
  durable `SharedPreferencesSaveStore` (survives restart). ✓
- Settings accessible + manual remove-ads → existing settings screen. ✓
- Analytics events for required fields → `AppController` logs + profile fields. ✓
- No interstitial during an active puzzle → interstitial only in `_handleWin`. ✓
- Core gameplay offline → pool is a bundled asset; only ad/purchase calls are
  network-bound (and are no-ops here). ✓

## Implementation decisions I made

- **Level ids derived from pool index** (`rs_000`…): the pool JSON has no
  `level_id` (Phase 2 `LevelData` omits it). The index is stable for the fixed
  committed asset and becomes the save-slot + completion + daily key.
- **`solver_steps_log` recomputed at level load** rather than stored in the pool:
  the pool doesn't carry it, and `HumanLikeSolver.analyze(givens, solution)` is a
  single cheap pass per level open. Avoids bloating the asset and keeps a single
  source of truth.
- **Hint = next *unsolved* step**: reveal the first step whose cell differs from
  the solution (empty or wrong-valued), so it corrects mistakes too. Fallback
  (log missing/exhausted): any empty cell from the solution.
- **Daily selection spans the whole pool** via FNV-1a(`YYYY-MM-DD`) mod 70 (not a
  single difficulty band). Measured: all 70 indices used over a year, 0
  consecutive-day repeats. Rationale: maximizes day-to-day variety; binding to one
  label would shrink variety and exhaust a label faster. Deliberately NOT
  `String.hashCode` (Dart randomizes it per run → not stable across launches).
- **Daily streak**: increments when the daily is completed on consecutive
  calendar days; same-day re-completion is a no-op; any skipped day resets the
  streak to 1 on the next completion.
- **Mistake check**: first per puzzle is free (`hasFreeCheck`), tracked by the new
  `checks_used`; the screen requires a rewarded ad afterwards.
- **Monetization thresholds** (`MonetizationPolicy`): interstitial every 3rd level
  complete; remove-ads offer after ≥5 completed levels OR ≥10 min session, AND ≥2
  interstitials since the last offer, capped at 3 offers lifetime. Suppressed once
  purchased. These are documented placeholders.
- **No level locking**: all levels are selectable. Locking/progression gating adds
  state and a progression model with no Phase 0 requirement for it; left for a
  later phase (noted in §7).
- **`PlayerProfile` is a `Snapshot`** at `app/profile`, so it reuses
  `SaveService.save(snapshot, trigger)` with no new storage code. Profile events
  map to existing triggers (`levelComplete`, `interstitialShown`,
  `rewardedAdCompleted`, `purchaseCompleted`); session-start and offer-shown have
  no dedicated Phase 0 trigger and use `appPause` as a generic flush.
- **Durable storage via `shared_preferences`** (persistence follow-up): the
  production store is now `SharedPreferencesSaveStore` (implements the unchanged
  Phase 1 `SaveStore`), so the profile + level snapshots survive app restarts.
  Chosen over a file-based JSON store because it is the official Flutter-team
  plugin, needs zero manual native setup, and is the smallest/standard fit for
  small key/value blobs; a file store would mean managing paths, directories, and
  IO error handling for no benefit at this size. It is the single new dependency
  (justified exception to the no-new-deps rule). `InMemorySaveStore` is kept for
  tests (fast, no platform channel). **Run `flutter pub get`** after pulling.
- **App icon via `flutter_launcher_icons`** (dev dependency): the standard,
  official-ish package for generating platform launcher icons from one source
  PNG (`assets/icon/icon.png`) — not worth hand-rolling per-platform resizing.
  Configured for Android (legacy + adaptive, with `adaptive_icon_foreground_inset:
  18` and a black adaptive background so the launcher mask doesn't clip the grid),
  iOS (`remove_alpha_ios` — iOS forbids alpha), and Windows (`.ico`). The source
  artwork is not modified; insetting + alpha removal happen only in the generated
  platform assets. Generate with `dart run flutter_launcher_icons`.

## Not implemented / deferred ideas

- **Real AdMob / Unity / Play Billing / StoreKit** — explicitly Phase 4; the
  no-op services + result types stay, wired to the game logic.
- **Level locking / progression** — *useful* for guided onboarding; *not now*
  (no requirement, adds a progression model); *later* a Phase 4 option.
- **Daily-puzzle calendar / history UI, leaderboards** — out of MVP scope.

## Specification ambiguities

- **Pool has no `level_id`** (Phase 0 §6.3 snapshots do): resolved by deriving a
  stable index id. **Review:** low-risk; revisit if the pool is ever reordered
  (completion data is keyed on the id).
- **Pool has no `solver_steps_log`**: recomputed at load. **Review:** none needed.
- **`checks_used` is a new snapshot field** beyond the Phase 0 §6.3 schema
  (needed for free/rewarded check tracking). **Review:** confirm before any
  cross-version save migration.
- **Two profile counters beyond Phase 0 §10** (`levels_since_interstitial`,
  `interstitials_since_last_offer`) are needed to implement the cadence + offer
  trigger. **Review:** confirm naming if §10 is treated as a fixed schema.
- **No dedicated save trigger** for session-start / offer-shown; reused
  `appPause`. **Review:** add trigger enum values if the analytics pipeline needs
  to distinguish them.
- **`ManualPuzzle` reused for pool levels**: it was the Phase 1 "hand-authored"
  fixture type but now also represents generated pool levels (same fields). A
  rename to `PuzzleData` would be cosmetic; left as-is to avoid churn.

## Persistence — verification

Automated (`test/persistence_test.dart`, run with `flutter test`): store
round-trip, and a simulated restart confirming `remove_ads_purchased`,
`completed_level_ids`, and `daily_streak` reload from `shared_preferences`.

Manual device/emulator scenarios (need a real Flutter environment — I cannot
force-close an app in this sandbox):

1. Complete a puzzle → force-close → reopen → the level shows as completed.
2. Buy "Remove Ads" (Settings) → force-close → reopen → no interstitials appear,
   and Settings shows it as owned.
3. Complete the daily puzzle → force-close → reopen the next calendar day →
   complete that day's daily → the streak increments (does not reset).

Setup: run **`flutter pub get`** first (new `shared_preferences` dependency). No
manual native/platform configuration is required for this plugin.
