# Chapter 1 Schema Freeze + ID Backfill — Result Report (Implementation Batch 1)

**Verdict: GREEN.** All 100 explicit ids match the historical positional ids, legacy loading
works, new loading works, puzzle content is equivalent, save keys unchanged, Daily mapping
unchanged, `flutter analyze` clean for the tracked tree, full test suite passes (142/142).

- **Branch:** `feature/chapter2-schema-freeze`
- **Base:** `feature/chapter2-data-model-design` @ `50ccb80b321d05fa8eb1724a882508d34cea8c68`
  (the reviewed Chapter 2 data-model design head; production `lib/` there is byte-identical
  to the approved inventory base `5927573`)
- **Scope:** Batch 1 only — freeze the fixed-level pool schema and pin the shipped Chapter 1
  level identities explicitly. No gameplay, progression, save, level-order, puzzle-content,
  or unlock behaviour change.

---

## 1. Files inspected (Step 0 trace)

| File | What was verified |
|---|---|
| `assets/levels/runic_sudoku_levels.json` | The shipped Chapter 1 pool. **Already an envelope** (`schema`, `note`, `grid_size`, `box_shape`, `counts`, `levels`), NOT a raw top-level list; 100 entries; every entry has exactly `grid_size`, `box_shape`, `solution_grid`, `given_cells`, `difficulty_label`, `estimated_solve_time`, `seed`; **no entry has `level_id`**; all scalars are ints/strings (no floats). |
| `lib/games/runic_sudoku/level_pool.dart` | `LevelPool.fromJsonString` read only `doc['levels']` (the `schema` marker string was ignored); `levelIdForIndex` derived identity purely from array position (`rs_${index padLeft 3}`); `_puzzleFromEntry(entry, index)` baked the positional id into `ManualPuzzle.levelId`. This was the **only** place ids were created. |
| `lib/games/runic_sudoku/manual_puzzle.dart` | `ManualPuzzle.levelId` is an opaque string; no parsing back out of it anywhere. |
| `lib/games/runic_sudoku/daily_puzzle.dart` | `DailyPuzzleSelector.indexForDate` = FNV-1a over `YYYY-MM-DD` modulo pool length. Depends only on date + pool length (100) + index→id mapping; independent of the envelope. |
| `lib/games/runic_sudoku/runic_sudoku_snapshot.dart` | `saveKeyFor(PuzzleMode.campaign, levelId)` → `runic_sudoku/<levelId>`; Daily/Free Play use fixed shared slots (`active_daily`, `active_freeplay`). |
| `lib/games/runic_sudoku/progression.dart` | Chapters (difficulty bands) built from `pool.presentLabels`/`byLabel`; consumes `p.levelId` opaquely. |
| `lib/games/runic_sudoku/runic_sudoku_controller.dart` | Consumes `puzzle.levelId` only via `saveKeyFor`; resumes shared-slot saves by comparing given-cell grids, not ids. |
| `lib/core/profile/app_controller.dart`, `player_profile.dart` | `completed_level_ids` is a flat opaque id set; only `onLevelCompleted` mutates it; `recordProgression` replaces only the derived cache. |
| `lib/main.dart`, `lib/app/app.dart`, `lib/app/main_menu_screen.dart` | `LevelPool.loadFromAsset()` once at startup; `dailyFor(DateTime.now())` in the menu. |
| `tool/generate_level_pool.dart` | Origin of the legacy envelope (`schema: runic_sudoku_level_pool_v1`); confirms repo JSON naming is `snake_case`. |
| Tests: `daily_puzzle_test.dart`, `progression_test.dart`, `persistence_test.dart`, `daily_persistence_test.dart`, `widget_test.dart`, `board_config_batch2_test.dart`, `free_play_test.dart`, `chapter_background_test.dart` | Pool fixtures are either in-memory `LevelPool([...])` constructions or minimal `{"levels":[...]}` JSON (incl. `{"levels":[]}` in `widget_test`); `board_config_batch2_test` reads the asset's `levels` list directly (unaffected by added envelope fields). No pre-existing reusable full legacy fixture existed → one was frozen in this batch (see §3). |

**Step 0 answers:** (1) current top-level JSON is an **envelope**, not a raw list (the batch
prompt's "legacy = raw list" assumption was adjusted to reality; the design report is
consistent with this). (2) Fields per entry: the seven listed above. (3) Array index was
permanent identity — only in `LevelPool`. (4) Nothing parses meaning back out of `rs_NNN`.
(5) Envelope changes don't affect asset loading (`rootBundle.loadString` + `jsonDecode`) or
Daily selection (date+length only). (6) No reusable full legacy pool fixture existed in
tests. No material deviation from the approved design report → no stop condition.

## 2. Files changed

| File | Change |
|---|---|
| `lib/games/runic_sudoku/level_pool.dart` | Schema-version dispatch: version 0 (no `schema_version` field) = exact legacy positional behaviour; version 1 = explicit `level_id` required per entry — missing/empty/duplicate id throws `FormatException` (no silent positional fallback); unknown versions rejected. Ids are opaque (no `rs_NNN` regex requirement). |
| `assets/levels/runic_sudoku_levels.json` | Converted by the deterministic backfill tool: envelope gains `schema_version: 1`, `chapter_id: "c1"`, `pool_version: 1`; every entry gains explicit `level_id` `rs_000`…`rs_099` equal to its historical position. All pre-existing envelope and entry fields preserved unchanged, in order. |
| `tool/backfill_chapter1_level_ids.dart` | **New.** One-time deterministic converter. Baseline = the Git blob `50ccb80:assets/levels/runic_sudoku_levels.json` via `git show` (never the working tree). Refuses to run unless the blob is exactly the expected legacy pool: 140 223 bytes, `schema` marker matches, no `schema_version`, exactly 100 entries, none with `level_id`, counts exactly Quick 20/Normal 30/Tricky 30/Deep 20. Idempotent: if the on-disk asset already equals the derived target, nothing is written. |
| `test/chapter1_schema_freeze_test.dart` | **New.** Golden + compatibility suite (19 tests, §5). |
| `test/fixtures/chapter1_pool_legacy_50ccb80.json` | **New.** Frozen legacy baseline — byte-identical copy of the Git blob at `50ccb80` (SHA-256 verified). Loaded through the production legacy (v0) parser in tests, so content-equivalence and Daily-stability tests compare against the true pre-freeze pool forever, not against a derived copy. |
| `docs/chapter1_schema_freeze_result.md` | **New.** This report. |

No other file was touched. `pubspec.yaml` unchanged (no new dependencies).

## 3. Pool shape: old → new

**Old (legacy, now "schema version 0"):** envelope `{schema, note, grid_size, box_shape,
counts, levels[100]}`; entries carry no id; identity = array position via
`levelIdForIndex`.

**New (schema version 1):**

```
{
  "schema": "runic_sudoku_level_pool_v1",   // legacy marker, preserved untouched (loader ignores it)
  "schema_version": 1,                       // authoritative version switch (absent = 0 = legacy)
  "chapter_id": "c1",
  "pool_version": 1,
  "note" / "grid_size" / "box_shape" / "counts": unchanged,
  "levels": [ { "level_id": "rs_000", ...all original fields unchanged... }, ... ]
}
```

Repo `snake_case` JSON convention followed (`schema_version`, `chapter_id`, `pool_version`,
`level_id`). Deliberately NOT added (later batches): `tierId`/tier model,
`ChapterDefinition`, `TierDefinition`, `CampaignRegistry`, `countsTowardProgress`,
`isOptionalExpert`, unlock policies, `level_order`, `progression_version 2`, any 9×9/12×12
content.

## 4. Asset provenance (SHA-256)

| Artifact | Size | SHA-256 |
|---|---|---|
| Baseline: Git blob `50ccb80:assets/levels/runic_sudoku_levels.json` | 140 223 B | `0c9fb10aab800a7c59f16e33836b7a7b3428a4f3047f6796e85b6c5d7bd88362` |
| Frozen fixture `test/fixtures/chapter1_pool_legacy_50ccb80.json` | 140 223 B | `0c9fb10aab800a7c59f16e33836b7a7b3428a4f3047f6796e85b6c5d7bd88362` (byte-identical to the blob) |
| Final asset `assets/levels/runic_sudoku_levels.json` (tool output) | 143 089 B | `69eab76bcf4802ec63b0e2d27478943ed9205048cc5c0e9fbe6d92195f02d670` |

Different whole-file hashes for baseline vs final are expected (envelope + ids were added);
content-equivalence is the correctness proof (§5). Determinism was additionally
cross-checked with an **independent second implementation** of the transformation (Python,
in the review sandbox): its output is byte-for-byte identical to the Dart tool's output
(same SHA-256 `69eab76b…`). The pre-conversion working-tree asset was verified byte-identical
to the Git blob before conversion, and the round-trip `strip(envelope+ids)` of the final
asset reproduces the baseline document exactly.

**Idempotence proof:** both captured tool runs (`dev_notes/freeze_backfill_run1.txt`,
`run2`) print `OK: assets/levels/runic_sudoku_levels.json already up to date (143089
bytes); nothing written.` — a run against an already-converted asset writes nothing and the
asset hash is unchanged.

## 5. Golden & compatibility verification (targeted suite)

`flutter test test/chapter1_schema_freeze_test.dart` → **19/19 passed** ("All tests
passed!", `dev_notes/freeze_test_targeted.txt`). Coverage:

1. **Exact identity mapping** — for every index 0–99, explicit id in the new asset equals
   the legacy positional id (`rs_000`…`rs_099`), i.e. the mapping result is
   `index i → rs_{i, 3 digits}` — identical before/after, all 100 indexes.
2. **Identity uniqueness** — exactly 100 non-empty unique ids; exact set `rs_000`…`rs_099`.
3. **Puzzle-content equivalence** — per index, the new asset's raw record minus `level_id`
   deep-equals the frozen Git-baseline fixture's record; parsed `ManualPuzzle`s are
   field-for-field identical (seed, grids, label, estimate); envelope fields `schema`,
   `note`, `grid_size`, `box_shape`, `counts` preserved.
4. **Difficulty bands** — exactly Quick 20 / Normal 30 / Tricky 30 / Deep 20, same order,
   same per-index label.
5. **Save keys** — `saveKeyFor(campaign, id)` = `runic_sudoku/rs_NNN` for all 100 levels.
6. **Completed-progress compatibility** — representative `completed_level_ids`
   (band boundaries + interiors: rs_000, rs_010, rs_019, rs_020, rs_042, rs_049, rs_050,
   rs_079, rs_080, rs_099) resolve to the same puzzles in both pools; derived
   `Progression` state (chapterProgress, computeUnlockedLevels/Chapters, nextLevelId,
   isFreePlayUnlocked) identical before/after. (`progression_version 2` NOT implemented —
   out of scope.)
7. **Daily Puzzle stability** — selected level id AND puzzle content identical
   before/after for **1100 consecutive dates** from 2026-01-01 (legacy pool from the
   frozen fixture vs new pool from the shipped asset, both through the production parser).
8. **Schema validation** — legacy pools (incl. empty `{"levels":[]}`) still load
   positionally; explicit-id pool loads; missing/empty/duplicate `level_id` rejected;
   unsupported `schema_version` rejected; a synthetic reordered two-entry v1 fixture
   (ids `alpha`/`beta` — also proves ids need no `rs_NNN` shape) keeps identity with the
   entries swapped, and array position no longer dictates identity.

## 6. Regression

- **Full suite:** `flutter test` → **142/142 passed** ("All tests passed!",
  `dev_notes/freeze_test_all.txt`; 123 pre-existing + 19 new). No existing test weakened
  or modified.
- **`flutter analyze`:** 30 issues, **all `info`-level** pre-existing lints in files this
  batch does not touch (`how_to_play_dialog.dart` 2, `settings_screen.dart` 2,
  `ads_service.dart` 6, `purchase_service.dart` 1, `calibrate_difficulty.dart` 6,
  `difficulty_metric_exploration.dart` 13); **0 errors, 0 warnings, 0 issues in any file
  changed by this batch** (`dev_notes/freeze_analyze2.txt`). An earlier log
  (`freeze_analyze.txt`) additionally showed 58 issues from the untracked local scratch
  folder `_to_delete/` (a leftover 12×12-prototype file the mounted dev VM could not
  delete); that folder was removed and the re-run above is authoritative.
- No puzzle content regenerated, no difficulty tuning, no Daily behaviour, no UI, no
  monetization/ads/IAP/Firebase/release-config changes.

## 7. Commit

Single commit on `feature/chapter2-schema-freeze`, message **"Freeze Chapter 1 level IDs
in pool schema"**, staged with an explicit file list (no `git add .`). `git diff --stat`
of the staged content files:

```
 assets/levels/runic_sudoku_levels.json          |   103 +
 lib/games/runic_sudoku/level_pool.dart          |    71 +-
 test/chapter1_schema_freeze_test.dart           |   285 +
 test/fixtures/chapter1_pool_legacy_50ccb80.json | 10714 ++++++++++++++++++++++
 tool/backfill_chapter1_level_ids.dart           |   123 +
 5 files changed, 11284 insertions(+), 12 deletions(-)
```

plus this report (`docs/chapter1_schema_freeze_result.md`, new file) added to the same
commit. The asset diff is exactly 103 inserted / 0 deleted lines — the 3 envelope fields
plus 100 `level_id` lines; nothing else in the file moved. Untracked local scratch
(`tool/audit_samples_9x9.json`, gitignored `dev_notes/`) deliberately excluded. Not
merged, not pushed — awaiting review.

## 8. Risks / follow-ups

- The `schema` legacy marker string (`runic_sudoku_level_pool_v1`) is preserved untouched
  and ignored by the loader; `schema_version` is the sole authoritative switch. A future
  batch may retire the marker when the c2 pool format is introduced — cosmetic only.
- `level_order` (design §F step 1) was deliberately deferred to the registry batch: order
  keeps coming from array position, which after this batch is a *presentation* concern,
  no longer an *identity* concern.
- The backfill tool is now inert (its guarded baseline is permanently frozen at `50ccb80`);
  it stays in `tool/` as provenance. Running it again is a safe no-op.
- Legacy (v0) parsing intentionally remains permissive (positional ids, `schema` ignored)
  so existing test fixtures and any legacy data keep loading byte-for-byte as today.

## 9. Scope statement

Explicitly confirmed: **no** Chapter 2 model (`ChapterDefinition`/`TierDefinition`/
`CampaignRegistry`), **no** Chapter 2 pool/content, **no** UI change, **no**
progression-semantics or unlock-policy change, **no** `progression_version` bump, **no**
Daily or Free Play behaviour change, **no** monetization/ads/IAP/Firebase/release-config
change was included in this batch. This commit changes only Chapter 1's *stored identity
representation* and its verification.
