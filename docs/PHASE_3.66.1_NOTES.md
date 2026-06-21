# Phase 3.66.1 — Deep Free Play: Bundled Pool + Rolling Cache

The Phase 3.65 Free-Play audit confirmed Deep on-demand generation (with the
3.66 guardrails) is too slow for a tap-to-play wait: P95 ≈ 2 s / P99 ≈ 3 s on PC
(~6–10 s on low-end Android), P95 rejections ≈ 602, 1 failure in 200. So Deep is
**never generated at tap time** anymore. It is served from two layers.

## 1. Architecture

- **Layer 1 — bundled pool.** 75 pre-generated guarded Deep puzzles shipped in
  `assets/freeplay/deep_pool.json` (ids `deep_fp_000`…`deep_fp_074`). Always
  available offline, instant.
- **Layer 2 — rolling cache.** Up to 15 puzzles generated in the background on a
  Dart isolate and persisted in `SharedPreferences` (key `deep_freeplay_cache`).
  Consumed first; the bundled pool is the permanent fallback.
- **`nextPuzzle()` is read-only and instant** (cache → bundled). No generation on
  the UI path. The Free Play Deep button and "Next Trial" both call it.
- **Background refill is paused during any gameplay** and on app pause/detach,
  and resumed when leaving a puzzle or opening the Free Play menu.
- **Dedup** via a stable `puzzleId`: bundled ids are fixed; cache ids are an
  FNV-1a hash of the given cells. `PlayerProfile.deepUsedIds` records shown
  puzzles so unseen ones are preferred; once all are seen it cycles (not marked
  "new").

## 2. New / modified files

New:
- `tool/generate_freeplay_deep_pool.dart` — offline builder for the bundled pool.
- `assets/freeplay/deep_pool.json` — 75 guarded Deep puzzles (generated, see §8).
- `lib/games/runic_sudoku/freeplay/deep_pool.dart` — `DeepPuzzleEntry`,
  `DeepBundledPool` loader, `deepIdFromGiven` hash.
- `lib/games/runic_sudoku/freeplay/deep_free_play_cache.dart` — `DeepFreePlayCache`.
- `test/deep_free_play_cache_test.dart`, `test/deep_pool_asset_test.dart`.
- `docs/PHASE_3.66.1_NOTES.md` (this file).

Modified:
- `core/profile/player_profile.dart` — `deepUsedIds` (+ JSON).
- `core/profile/app_controller.dart` — `deepUsedIds` getter + `markDeepUsed`.
- `app/app.dart` — `AppServices.deepCache` (optional); both screen builders pass
  it through.
- `app/free_play_screen.dart` — Deep served from the cache (instant; overlay only
  if a read exceeds 200 ms); refill resumed on entry; Quick/Normal/Tricky still
  generated on-demand via `compute`.
- `games/runic_sudoku/runic_sudoku_screen.dart` — pause refill on puzzle
  start/app-pause, resume on leave.
- `main.dart` — load bundled pool + cache; refill immediately if cache < 5, else
  defer to first menu/puzzle exit.
- `pubspec.yaml` — bundle `assets/freeplay/deep_pool.json`.

## 3. Cache service behaviour

`nextPuzzle()`: if the rolling cache is non-empty, pop one (prefer unseen),
persist, mark used, return it; else pick from the bundled pool (prefer unseen,
else cycle a random one), mark used; else return null (only if no pool shipped).

`startRefill()` / `stopRefill()`: a single async loop generates one puzzle per
isolate (`compute`), commits it, then checks whether to continue.
`stopRefill()` flips the flag — the in-flight isolate result is discarded
(`compute` can't be hard-killed, so the current puzzle finishes then is dropped;
no further work is queued). A consecutive-miss bound (60) guarantees the loop can
never spin forever on a degenerate/duplicate generator.

## 4. Lifecycle

`main.dart` loads the persisted cache; if `< 5`, refill starts immediately,
otherwise it is deferred (the Free Play menu's `initState` and leaving the first
puzzle both trigger `startRefill`). The play screen calls `stopRefill()` in
`initState` and on `paused`/`inactive`/`detached`, and `startRefill()` in
`dispose`. Net effect: refill runs only while the player is on menus, never
during a puzzle or in the background.

## 5. Tests

- `deep_free_play_cache_test.dart`: cache-first consumption; bundled fallback;
  prefer-unseen; null only when both empty; `deepUsedIds` updates; refill fills to
  max; `stopRefill` discards in-flight; constant-generator dedup terminates.
- `deep_pool_asset_test.dart`: the shipped asset exists, has 75 entries, every
  solution is a valid complete 6×6, every given is a subset of its solution, and
  all ids + given patterns are unique.
- Existing tests unchanged (all additions are additive with defaults;
  `AppServices.deepCache` is optional so `widget_test` still compiles).

## 6. Implementation decisions

- **One isolate per puzzle** (`compute`) rather than a long-lived spawned isolate
  with a cancel port — far simpler and safe; cancellation = "don't start the
  next one," matching the spec's "generate one, then check whether to continue."
- **`deepUsedIds` lives in `PlayerProfile`** (per spec), grows unbounded (tiny).
  `markDeepUsed` persists but does not `notifyListeners` (no UI depends on it).
- **Deep reuses one save slot** (`freeplay_deep`, loaded `fresh`) like the other
  Free Play difficulties — ephemeral, no resume.
- **Quick/Normal/Tricky are unchanged** (on-demand `compute`); only Deep uses the
  pool/cache, since only Deep is slow.
- **Miss bound (60)** added to the refill loop to make it provably terminating.

## 7. Not implemented / deferred / ambiguities

- The "defer refill to after the first puzzle" requirement is realised via the
  screen-`dispose`/menu-`initState` hooks rather than an explicit one-shot timer
  in `main`; same intent (don't compete with startup), simpler wiring.
- `compute` cannot be hard-cancelled, so a single in-flight Deep generation may
  finish (and be discarded) after `stopRefill()`. Acceptable — it is one
  background puzzle, never on the UI thread; documented above.
- AppLifecycle is exercised through the cache's own start/stop unit tests rather
  than a full widget-lifecycle test (kept light; the screen wiring is trivial).
- No UI to browse Free Play stats / used-pool progress (out of scope).

## 8. Pool generation result

The sandbox has **no Dart SDK**, so `tool/generate_freeplay_deep_pool.dart` could
not be executed here. The shipped `assets/freeplay/deep_pool.json` was produced by
the validated Python port of the exact generator + guardrails (same algorithm the
Dart tool runs) and verified programmatically:

- 75 puzzles, **0 duplicate** given patterns, all solution grids valid complete
  6×6, every given ⊆ its solution.
- candidate_complexity: min 0.300, avg 0.313, max 0.343 (all genuine Deep).
- blanks: min 25, avg 26.8, max 28.
- estimated_solve_time: 390 000–441 111 ms.
- generation cost (Python port, guarded Deep): avg ~150 rejections/puzzle — the
  reason this is an offline asset, not on-demand.

Re-running `dart run tool/generate_freeplay_deep_pool.dart` on a machine with the
Flutter SDK will regenerate an equivalent 75-puzzle pool in the same format.
