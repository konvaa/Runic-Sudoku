# Chapter 2 Static Contract — Result Report (Implementation Batch 2)

**Verdict: GREEN.** Static Chapter/Tier/Registry contract introduced; Chapter 1 fully
modeled over it; the differential golden test passes with **zero output differences across
the full 640-set corpus (74 885 individual comparisons, actual Dart run)**; no threshold
frozen, no `progression_version` bump, no live wiring; `flutter analyze` clean for the
tracked tree; full suite 154/154.

- **Branch:** `feature/chapter2-static-contract`
- **Base:** `525c13ae33d8503ab0c97e53ad9107f4147d0bd2` ("Freeze Chapter 1 level IDs in
  pool schema", the reviewed Batch 1 head). Working tree verified clean before work.
- **Scope:** architecture only — a parallel, testable registry implementation beside the
  live `Progression` model, proven behaviourally identical, **not** load-bearing.

---

## 1. Step 0 — traced formulas and call sites

### Current unlock/progress formula set (verbatim semantics, `progression.dart`)

- `Progression.fromPool`: one band-"chapter" per label present in
  `LevelPool.labelOrder` (`Quick, Normal, Tricky, Deep`); `chapterId = 'chapter_$order'`
  (positional); display names from `_displayNames`
  (`Quick Runes / Normal Seals / Tricky Glyphs / Deep Chambers`).
- `thresholdFor(chapter) = (chapter.size × chapterUnlockFraction).ceil()`, fraction
  default **0.5** — computed from **live** chapter size (today: 10/15/15, and 10 for the
  successor-less Deep band).
- `isChapterUnlocked(id)`: order 1 → `true`; else
  `completedInChapter(chapters[order−2]) >= thresholdFor(chapters[order−2])`
  (prerequisite by **array position**).
- `isLevelUnlocked(id)`: `completed.contains(id)` → `true` (replay; holds even for ids
  unknown to the pool); unknown meta → `false`; chapter locked → `false`;
  `levelOrder == 1` → `true`; else previous level in the chapter completed.
- `computeUnlockedLevels`: per unlocked chapter — index 0 plus every level whose
  predecessor is completed; then `∪ (completed ∩ levelsById.keys)` (completed levels stay
  replayable even in locked chapters; unknown completed ids are NOT emitted).
- `computeUnlockedChapters`: `{ id | isChapterUnlocked }`.
- `chapterProgress`: per chapter (locked included) the completed-membership count.
- `nextLevelId`: chapters in order, skip locked; first level that is not completed and
  `isLevelUnlocked`.
- `isFreePlayUnlocked`: `completedInChapter(first) >= thresholdFor(first)`.

### Consumers of `Progression`/`ChapterMeta` today

- `lib/main.dart:67` — `Progression.fromPool(levelPool)`, passed into
  `ProgressionController` (the only construction site).
- `lib/games/runic_sudoku/progression_controller.dart` — all queries
  (`isLevelUnlocked`, `isChapterUnlocked`, `freePlayUnlocked`, `nextLevelId`/`isNext`,
  `completedInChapter`) + `_sync` → `AppController.recordProgression` (persists derived
  sets).
- `lib/app/app.dart` — carries the `Progression` instance in the services bundle.
- `lib/app/level_select_screen.dart` — `progression.chapters`, per-chapter unlock/
  progress, `levelsById[...].unlockRequirement` strings, `isNext`.
- `lib/app/main_menu_screen.dart` — `chapters.first`, `thresholdFor` (with a hardcoded
  fallback `10` when the pool is empty), `freePlayUnlocked`.
- `lib/games/runic_sudoku/chapter_theme.dart` — `levelsById[levelId]?.difficultyLabel`.
- Tests: `progression_test.dart`, `free_play_test.dart`, `persistence_test.dart`,
  `widget_test.dart`, `chapter_background_test.dart`, `chapter1_schema_freeze_test.dart`.

**Post-Batch-1 confirmation:** `app_controller.dart` / `progression_controller.dart` were
untouched by the schema freeze (Batch 1 changed only `level_pool.dart`, the asset, tests,
tool, docs). **Isolated parity testing confirmed feasible** — `Progression` is a pure
class constructible from a `LevelPool` in tests; the registry side is equally pure, so the
differential test runs entirely in `test/` with no live wiring. No stop condition.

## 2. Files changed (all new; zero existing files modified)

| File | Content |
|---|---|
| `lib/games/runic_sudoku/chapter_registry.dart` (357 lines) | The static contract: `ChapterUnlockPolicy` (+type enum), `TierUnlockPolicy` (+type enum incl. `disabled`), `LevelDefinition`, `TierDefinition`, `ChapterDefinition`, `CampaignRegistry` (levelsById union with duplicate-id guard, `chapterById`/`chapterOf`/`tierOf`), and the `CampaignRegistry.chapter1FromPool` builder (c1 → tiers `quick`/`normal`/`tricky`/`deep`, explicit prerequisite tier ids, today's exact display names, `BoardConfig.sixBySix`, complete-coverage guard). |
| `lib/games/runic_sudoku/registry_progression.dart` (187 lines) | `RegistryProgression` — the independent registry-driven evaluator: `completedInTier`, `requiredFromPrerequisite` (= live `ceil(size × unlockFraction)`), `isChapterUnlocked`, `isTierUnlocked`, `isLevelUnlocked`, `computeUnlockedLevels`, `computeUnlockedTiers`, `tierProgress`, `nextLevelId`, `isFreePlayUnlocked`. **Does not import `progression.dart`** — no delegation to legacy methods for any compared output (the only sharing is the immutable `ManualPuzzle` payload and the pool asset, as permitted and here reported). |
| `test/chapter2_static_contract_differential_test.dart` (272 lines) | The differential golden test (§4). |
| `test/chapter_registry_test.dart` (229 lines) | Contract unit tests: c1 registry structure/lookups/axis separation, construction guards (duplicate id, unmapped label), synthetic policy evaluation (chapter core-count gate counts only `countsTowardProgress` tiers; `disabled` tier never unlocks but completed levels stay replayable; missing prerequisite fails closed). Synthetic thresholds are arbitrary test values, not shipped constants. |
| `docs/chapter2_static_contract_result.md` | This report. |

`lib/main.dart`, `ProgressionController`, `AppController`, persistence, UI, pubspec: **not
touched** (verifiable from the commit's file list — the commit contains only the five new
files above).

## 3. Hard-boundary compliance

- **No threshold freeze.** `TierUnlockPolicy` deliberately has **no numeric field**; a
  `completedCountInTier` gate is evaluated live as
  `ceil(currentPrerequisiteTierSize × unlockFraction)` (fraction 0.5, same default as
  legacy), independently implemented in `RegistryProgression.requiredFromPrerequisite`.
  The values 10/15/15 appear only as *expected results of the live formula* in test
  assertions, never as stored configuration. The future freeze point is marked with a
  `TODO(frozen-thresholds batch)` on both the policy type and the evaluator field; the
  live-size relock hazard (design must-close #5/#6) intentionally still exists — parity
  first, freeze next batch.
- **No `progression_version` bump**, no persistence-migration logic, no profile key-shape
  change. The new `c1`/tier identifiers exist only in memory and in test assertions.
- **No live wiring.** The registry is constructed only inside the two test files.
- `ChapterUnlockPolicy.completedCoreCountInChapter` exists as the target shape with
  evaluation logic, exercised **only** by synthetic unit-test data; no shipped instance
  carries a gate (c1 is `initiallyUnlocked`; the real c2 gate belongs to the Chapter 2
  content batch).

## 4. Differential golden test — corpus and result (actual Dart run)

Legacy `Progression` and `RegistryProgression` run side-by-side over every corpus set;
per set the compared outputs are: unlocked level ids, unlocked tier/band state (via the
test-only adapter `chapter_1→c1/quick, chapter_2→c1/normal, chapter_3→c1/tricky,
chapter_4→c1/deep`), progress values, live thresholds, next level, Free-Play unlock,
per-level availability for all 100 ids (covers replayability), and availability of every
unknown id present in the set.

Corpus (fully deterministic, **seed `0xC0FFEE`**, local MINSTD LCG independent of SDK
`Random`): 1 empty + 9 boundary sets (prefix and scattered on both sides of 9/10 and
14/15, plus threshold-met-in-locked-band variants) + **all 101 prefixes** k=0..100 + 4
tiers fully completed in isolation + 1 fully completed pool + **520 randomized sets**
(130 sparse, 130 medium, 130 dense, 65 tier-local, 65 cross-tier) + 4 unknown-id sets
(`rs_999`, foreign-namespace and garbage ids mixed into valid sets) = **640 compared
profile states**.

Result — quoted from the executed run (`dev_notes/contract2_test_targeted.txt`):

```
differential corpus: seed=0xc0ffee, 520 randomized sets, 640 compared profile states,
74885 individual output comparisons, zero differences
00:00 +12: All tests passed!
```

Structural parity is additionally asserted directly: identical level-id lists and order
per band/tier, identical display names and difficulty labels, identical id universe
(100), explicit-id prerequisites, and live thresholds equal to the legacy formula's
current values.

**First run was RED — disclosed for the record.** The first local run
(`dev_notes/contract_test_targeted.txt`) failed to compile: `tier.size` on a
`List<String>` in the differential test (a `TierDefinition.size` vs `List.length` API
slip; the pre-run cross-check had been a Python re-implementation, where `len()` masked
exactly this class of error — that simulation validated semantics, not the Dart
artifact). Separately, `chapter_registry_test.dart` exposed a real guard gap:
`chapter1FromPool` silently **dropped** levels whose difficulty label has no tier mapping
(`pool.presentLabels` filters to the known label order, so the original null-check was
unreachable). Fixes: `tier.length`, and a complete-coverage guard that walks
`pool.levels` and throws `ArgumentError` (naming label and level id) for any unmapped
label — the test was not weakened. The guard makes registry *construction* stricter than
legacy's silent drop; it is construction-time only and produces **zero** differential
output differences (the shipped pool has only the four mapped labels). All three
verification steps were then re-run from scratch (fresh `contract2_*` logs); the numbers
above are from that complete re-run.

## 5. Regression (fresh full run, `contract2_*` logs)

- **Targeted:** `flutter test test/chapter2_static_contract_differential_test.dart
  test/chapter_registry_test.dart` → **12/12 passed** (`contract2_test_targeted.txt`).
- **`flutter analyze`:** 30 issues, all pre-existing `info`-level lints in files this
  batch does not touch (same set as the Batch 1 report); **0 errors, 0 warnings, 0
  issues in any Batch 2 file** (`contract2_analyze.txt`).
- **Full suite:** `flutter test` → **154/154 passed** (142 pre-existing + 12 new;
  `contract2_test_all.txt`). No existing test modified or weakened.

## 6. Design §B adaptations (documented deviations, all cosmetic)

- `displayName` holds today's exact UI strings instead of `displayNameKey` — the app has
  no l10n infrastructure; the key indirection lands with localization. No new names.
- `difficultyLabel` kept as the pool's string token (matches `ManualPuzzle`/pool shape)
  rather than the `DifficultyLabel` enum.
- `LevelDefinition` wraps the existing immutable `ManualPuzzle` as its payload instead of
  duplicating grid fields.
- Omitted until needed: `levelNamespace` (meaningless for c1's legacy `rs_*` ids),
  `TierAvailability` (arrives with the gated Expert tier), chapter-level `displayName`
  (no current UI shows a roadmap-chapter name).

## 7. Risks / follow-ups

- The live-size relock hazard is intentionally preserved (parity). **Next batch:** freeze
  tier/chapter thresholds to absolute versioned counts (design G8), then the
  `progression_version 1→2` bump, then live cutover — each separately reviewed.
- At cutover time, `LevelMeta.unlockRequirement` strings, `chapter_theme`'s label lookup,
  and `main_menu_screen`'s hardcoded empty-pool fallback (`10`) must be re-homed onto the
  registry; they remain legacy-owned today.
- The test-only band→tier adapter must never leak into migration logic (per prompt; it
  lives only inside the differential test).

## 8. Scope statement

Explicitly confirmed: **no** Chapter 2 pool/content, **no** 9×9/12×12 anything, **no** UI
change, **no** new fantasy display names, **no** frozen absolute thresholds, **no**
non-relock fix or monotonic high-water union, **no** `progression_version` bump or
persistence-migration logic, **no** Daily Puzzle/Free Play behaviour change, **no**
Firebase/ads/IAP/monetization change, **no** wiring of `CampaignRegistry` into
`main.dart`/`ProgressionController`/`AppController`/any live runtime or persistence path,
**no** delegation from the new evaluator to legacy `Progression` for compared outputs.

## 9. Commit

Single commit on `feature/chapter2-static-contract`, message **"Introduce Chapter/Tier
registry over Chapter 1 (behavioral parity, no threshold freeze)"**, staged with an
explicit file list: the four new source/test files (§2) plus this report — five new
files, zero modified. Not merged; **not pushed** (per batch instructions, push only after
review and explicit confirmation).
