# Chapter 2 Fixed-Level Data Model — Design Investigation (Step 1, no code changes)

**Branch:** `feature/chapter2-data-model-design` (created from `feature/chapter-system-inventory` @ `5927573` — the reviewed Batch 1/2 `BoardConfig` foundation). NOT based on any spike branch. Nothing merged. No production Dart, save data, pools, or UI were modified.

**Inspection basis:** The working tree currently sits on `feature/9x9-free-play-guardrails` (`bc6f338`), but `git diff --stat 5927573 bc6f338 -- lib/` is **empty** — every production `lib/` file is byte-identical to the approved base. The two spikes (`6ff6870`, `bc6f338`) changed only `docs/`, `test/`, and `tool/`. So the code traced below is exactly the Batch 1/2 foundation.

**Verdict:** The persistence model is **NOT too ambiguous** to design a safe migration (stop-condition not triggered). It is, in fact, unusually favourable: the only durable campaign truth is `completed_level_ids` plus the per-level active snapshots; every unlock/chapter structure is re-derived from that set on each launch. A Chapter 2 model that keeps `completed_level_ids` semantics intact is inherently non-destructive to Chapter 1 progress. Two latent hazards must be fixed as part of the work: (1) positional `rs_NNN` level identity, and (2) chapter-unlock thresholds computed from *live* chapter size, which can silently re-lock an already-earned chapter when a chapter grows.

---

## Executive summary (the five must-close items)

1. **Is level ID explicit or positional?** → **Positional.** `rs_NNN` is derived from the entry's index in `runic_sudoku_levels.json` (`LevelPool.levelIdForIndex`); the JSON has no `level_id` field (verified: 100 entries, none carry `level_id`). This id is the save-slot key *and* the completion key. Reordering the pool silently remaps all saved progress. **This is the first thing to fix — Chapter 2 pools MUST carry explicit `level_id`.**
2. **Chapter 1 progress preservation.** → Guaranteed, with no reset and no re-interpretation, provided `completed_level_ids` (the `rs_NNN` set) keeps its meaning and derived state is recomputed. The migration does not touch that set.
3. **Active-save separation.** → Campaign active games are already keyed per level (`runic_sudoku/rs_NNN`); Chapter 2 uses a disjoint namespace (`c2_*`), so 6×6 and 9×9 active campaign games never share a slot. The *single* Daily / Free Play slots (`active_daily`, `active_freeplay`) are board-ambiguous and are the only real collision risk — but both are out of scope here (see §Scope 6).
4. **Unlock counts core only.** → Designed via an explicit `countsTowardProgress` flag on each tier; Expert is excluded from both numerator and denominator of chapter completion and from any next-chapter unlock gate.
5. **Future core levels must not re-lock a chapter.** → The current model **violates this today**: unlock thresholds are `ceil(size × 0.5)` computed from the *current* chapter size, recomputed every launch. Growing a chapter raises its threshold and can retro-lock a chapter a player already opened. The design freezes unlock thresholds as versioned absolute counts.

---

## A. Current-state inventory table

Risk = impact × likelihood of breaking Chapter 1 saves or Chapter 2 correctness if left unaddressed.

| # | File | Class / function | Current assumption | Why Chapter 2 affects it | Risk |
|---|------|------------------|--------------------|--------------------------|------|
| A1 | `games/runic_sudoku/level_pool.dart` | `LevelPool.levelIdForIndex`, `_puzzleFromEntry` | Stable level id = **array position** (`rs_000`…); pool JSON stores no `level_id`. | Chapter 2 needs stable ids independent of file order; positional ids re-introduce the reorder-corruption hazard on a second, growing pool. | **HIGH** |
| A2 | `games/runic_sudoku/progression.dart` | `Progression.fromPool`, `ChapterMeta` | "Chapter" == one **difficulty band** of a single pool (`chapter_1`=Quick … `chapter_4`=Deep); id = `'chapter_$order'` (positional). | Roadmap "Chapter 2" is a different axis (a board/level-set). The word "chapter" is overloaded; band-chapters and roadmap-chapters collide in id space and in persisted `unlocked_chapter_ids` / `chapter_progress`. | **HIGH** |
| A3 | `games/runic_sudoku/progression.dart` | `thresholdFor`, `isChapterUnlocked` | Unlock threshold = `ceil(chapter.size × 0.5)` from **live** size; recomputed each launch. | Adding core levels to any chapter later raises the threshold and can re-lock an already-unlocked chapter (violates must-close #5). | **HIGH** |
| A4 | `games/runic_sudoku/progression.dart` | `_displayNames`, `ChapterMeta.displayName` | Display name is **derived from the difficulty label** (Quick→"Quick Runes"). | Chapter 2 fantasy names (Opening Seals, Woven Runes, …) must be UI-only and decoupled from tier identity and from `DifficultyLabel`. | MEDIUM |
| A5 | `core/profile/player_profile.dart` | `PlayerProfile` (`completed_level_ids`, `unlocked_chapter_ids`, `chapter_progress`, `progression_version`) | Flat id sets; chapter progress keyed by `chapter_N`; one global `completed_levels_count`; `progression_version` reserved, unused. | c2 ids extend the flat set safely, but `chapter_progress` keys and the global count cannot express per-chapter (c1 vs c2) core completion. `progression_version` is the migration hook. | MEDIUM |
| A6 | `core/profile/app_controller.dart` | `recordProgression`, `AppController.load` | Persists derived unlock sets; **re-derived from `completed` at every startup** via `ProgressionController.ensureInitialized`. | This is the safety net: model changes re-derive cleanly. Must be preserved and made version-aware. | LOW (asset) |
| A7 | `games/runic_sudoku/runic_sudoku_snapshot.dart` | `saveKeyFor`, `RunicSudokuSnapshot` | Campaign slot = `runic_sudoku/<levelId>`; Daily/Free Play each **one** shared slot (`active_daily`, `active_freeplay`); board identity (`grid_size`,`box_shape`) stored per snapshot. | Campaign c2 slots are naturally disjoint. Daily/Free Play single slots become board-ambiguous once a 9×9 variant exists (out of scope, but must be flagged). | MEDIUM |
| A8 | `games/runic_sudoku/daily_puzzle.dart` + `level_pool.dart` `dailyFor` | `DailyPuzzleSelector.indexForDate` | Daily = `FNV(date) % levels.length` over the **whole single pool**; depends on pool length and order. | If c2 levels are merged into the same `levels` array, the daily selection shifts for all users *and* every `rs_NNN` positional id moves. Chapter 2 pool must stay a **separate** asset/pool. | **HIGH** (if pools merged) |
| A9 | `games/runic_sudoku/freeplay/deep_free_play_cache.dart` | `cacheKeyFor`, `deep_freeplay_cache_6x6` | Rolling Deep cache already **namespaced by board token**; legacy unnamespaced key removed on load; bundled pool is 6×6-only. | Good precedent for board-scoped keys. A 9×9 Deep needs its own bundled pool; cache keying already scales. | LOW |
| A10 | `games/runic_sudoku/freeplay/deep_pool.dart` | `deepIdFromGiven` (`deep_c_…`), bundled `deep_fp_NNN` | Deep puzzle ids not disambiguated by board (FNV of givens only). | 6×6/9×9 ids theoretically share the `deep_c_` space; also `deep_used_ids` mixes boards. Cosmetic today (Free Play scope). | LOW |
| A11 | `app/free_play_screen.dart` | `generateFreePlayPuzzle`, `_freePlayMaxAttempts` | On-demand Free Play hardwired to `BoardConfig.sixBySix`; attempt budgets 6×6-tuned; slot id `active_freeplay`. | 9×9 Free Play would need per-board budgets + a board-scoped slot. Out of scope; flagged. | LOW |
| A12 | `core/profile/player_profile.dart` | `freePlaysBestTimes` (keyed by label), `deepUsedIds` | Best times keyed by difficulty label only, not board. | 9×9 Deep best time would overwrite 6×6 Deep. Free Play scope; flagged. | LOW |
| A13 | `games/runic_sudoku/chapter_theme.dart` | `ChapterBackgrounds._byLabel` | Backgrounds keyed by difficulty label; four 6×6 art assets. | Chapter 2 may reuse label→art or want per-chapter art; keying is label-based, chapter-agnostic. Additive. | LOW |
| A14 | `core/theme/rune_set.dart` | `elderFutharkNineSet` | 9-rune set exists, order load-bearing, first 6 == 6-set; **not registered / not reachable**. | Chapter 2 9×9 needs this wired to a theme + `requireSymbolCount(9)`. Groundwork already laid (Batch 2). | LOW |
| A15 | `games/runic_sudoku/runic_sudoku_rules.dart` | `RunicSudokuRules.sixBySix`, `requireSymbolCount` | Rules preset + symbol-count validation tuned to 6×6 (board-parametric constructor exists). | c2 needs a 9×9 rules preset; constructor already takes dimensions/box, so additive. | LOW |
| A16 | `games/runic_sudoku/solver/difficulty_constants.dart` | `DifficultyTuning` (all constants) | Thresholds derived from **measured 6×6 data**. | Do NOT reuse blindly for 12×12 Expert; 9×9 feasibility already GREEN with no tuning change. Out of scope to change here. | MEDIUM (Expert only) |
| A17 | `main.dart` | startup wiring | Builds exactly one `LevelPool`, one `Progression.fromPool`, one `DeepFreePlayCache`. | Chapter 2 requires a multi-chapter registry (list of chapters/pools) rather than a single pool/progression. | MEDIUM |

---

## Separation of concepts (the eight axes the prompt requires)

The design keeps these **eight** independent, per the confirmed principle that `tierId` (stable identity), `difficultyLabel` (generation/calibration profile) and `displayName` (fantasy UI) are three different things:

| Axis | Meaning | Example (c2) | Persisted? | Never derived from |
|------|---------|--------------|-----------|--------------------|
| `chapterId` | Stable identity of a chapter (board/level-set). | `c2` | Indirectly (embedded in `levelId`) | fantasy name |
| `tierId` | Stable identity of a tier within a chapter. | `quick`,`normal`,`tricky`,`deep`,`expert` | Indirectly (in `levelId`) | fantasy name, `DifficultyLabel` |
| `difficultyLabel` | Generation / calibration profile (`DifficultyLabel` enum). | `deep` | In snapshot / pool JSON | tierId (Expert has none until calibrated) |
| `displayNameKey` | Localization key for fantasy UI name. | `chapter.c2.tier.tricky.name` → "Ritual Chambers" | asset/loc only | identity |
| `boardConfig` | Board identity (dims, box, runeCount). | 9×9 / 3×3 / 9 | In pool + snapshot JSON | tierId |
| `countsTowardProgress` | Whether a tier's levels count to chapter completion / next-chapter unlock. | `true` for core, `false` for Expert | In chapter definition (code/asset) | — |
| `isOptionalExpert` | Marks the optional, gated Expert tier. | `true` only for `expert` | In chapter definition | — |
| `levelId` / namespace | Stable, explicit per-level id. | `c2_tricky_007` | **Yes — durable** | array position |

Critical rule: **`levelId` is not `chapterId`, is not `tierId`, is not `difficultyLabel`, is not the fantasy name.** It is an opaque, explicitly-stored string whose *format* happens to embed chapter+tier for readability, but code must treat it as opaque (never parse it to recover identity — identity comes from the level's stored `chapterId`/`tierId` fields).

---

## B. Proposed minimum data contract (design only — pseudocode, not implementation)

Only the abstractions that solve a concrete current requirement are introduced. No speculative layers.

```text
// ---- Static definitions (code + bundled asset; NOT player data) ----

ChapterDefinition {
  chapterId            : String        // 'c1', 'c2'         — stable, opaque
  order                : int           // 1, 2               — display/sequence only
  displayNameKey       : String        // loc key; fantasy name lives in l10n
  coreBoardConfig      : BoardConfig    // c1: 6x6/2x3/6, c2: 9x9/3x3/9
  tiers                : List<TierDefinition>
  unlockPolicy         : ChapterUnlockPolicy   // how THIS chapter unlocks (see E)
}

TierDefinition {
  tierId               : String        // 'quick'|'normal'|'tricky'|'deep'|'expert'
  displayNameKey       : String        // fantasy name loc key (UI only)
  difficultyLabel      : DifficultyLabel?   // generation/calibration profile;
                                            // NULL for 'expert' until 12x12 calibrated
  boardConfig          : BoardConfig    // usually == chapter.coreBoardConfig;
                                        // Expert overrides to 12x12/4x3/12
  countsTowardProgress : bool          // core = true; expert = false
  isOptionalExpert     : bool          // true only for the Expert tier
  levelNamespace       : String        // 'c2_quick' -> ids 'c2_quick_001', ...
  availability         : TierAvailability  // enabled | disabledUntilCalibrated
}

LevelDefinition {          // one bundled puzzle (from the chapter's pool asset)
  levelId              : String        // 'c2_tricky_007' — EXPLICIT in JSON, durable
  chapterId            : String        // 'c2'  (stored, not parsed from levelId)
  tierId               : String        // 'tricky'
  boardConfig          : BoardConfig    // board identity for this level
  givenCells           : int[][]       // canonical puzzle data (Phase 0 truth)
  solutionGrid         : int[][]       // canonical solution
  estimatedSolveTime   : Duration?     // display/sort
  seed                 : int?          // debug breadcrumb only
}

// Pool-file envelope (per chapter asset), carries versions so old files are detectable:
PoolFile {
  schemaVersion        : int           // bump when LevelDefinition shape changes
  chapterId            : String
  poolVersion          : int           // bump when levels added/changed (see E)
  levels               : List<LevelDefinition>   // each with explicit levelId
}

// ---- Player data (persisted; extends the existing PlayerProfile) ----

// completed_level_ids stays a flat Set<String> of opaque levelIds (rs_* AND c2_*).
// Chapter/tier completion is DERIVED by resolving each completed id through the
// static registry, so no new per-chapter persisted counters can drift.

// Replaces the single positional-band 'chapter_progress' map with a
// chapter-scoped, tier-aware derived structure (still recomputed from `completed`):
//   completionByChapter: { 'c1': {core: 100/100}, 'c2': {core: 12/160, expert: excluded} }
```

The registry that ties it together (built once at startup, replaces the single `Progression.fromPool`):

```text
CampaignRegistry {
  chapters            : List<ChapterDefinition>          // c1, c2 (expert tier gated off)
  levelsById          : Map<String, LevelDefinition>     // union across all chapter pools
  chapterOf(levelId)  -> ChapterDefinition
  tierOf(levelId)     -> TierDefinition
  // Progression queries (unlock, next, %) operate over this registry + completed set.
}
```

---

## C. Stable ID and namespace rules

**Level ids (durable).**
- Chapter 1 keeps its existing ids **exactly**: `rs_000 … rs_099`. No rename, ever (they are live save keys).
- Chapter 2 core levels: `c2_<tier>_<NNN>` — `c2_quick_001`, `c2_normal_001`, `c2_tricky_001`, `c2_deep_001`.
- Chapter 2 Expert (future, gated): `c2_expert_001` in its own namespace so a 12×12 level can never collide with a 9×9 `c2_deep_*` id.
- Ids are **stored explicitly** in every Chapter 2 pool file and are **treated as opaque** by code. The `c2_tier_NNN` shape is for human readability only; identity is read from the level's stored `chapterId`/`tierId`, never parsed back out of the string.
- Recommendation (hardening, see D-option): backfill explicit `level_id: "rs_000"…` into the Chapter 1 pool asset equal to today's derived values, so Chapter 1 identity is also pinned against accidental reorder. This is byte-for-byte progress-neutral (ids are unchanged) but removes the positional hazard for both chapters.

**Save-slot keys (durable).**
- Campaign active game: `runic_sudoku/<levelId>` — unchanged. `c2_*` ids are naturally disjoint from `rs_*`, so no collision and no ambiguity between 6×6 and 9×9 active campaign games.
- Profile: `app/profile` — unchanged.
- Daily / Free Play single slots (`runic_sudoku/active_daily`, `runic_sudoku/active_freeplay`): keep as-is for Chapter 1. When (and only when) a board-varying Daily/Free Play ships, extend the key with a board token (mirroring the existing `cacheKeyFor(board)` → `deep_freeplay_cache_9x9` precedent). Out of scope now; see §Scope 6.
- Deep rolling cache: already `deep_freeplay_cache_<boardToken>` — scales unchanged.

**Chapter / tier ids (identity, not display).**
- `chapterId ∈ {c1, c2}`, stable and opaque. `tierId ∈ {quick, normal, tricky, deep, expert}`, stable and opaque.
- Fantasy names (Opening Seals, Woven Runes, Ritual Chambers, Arcane Grid, Twelvefold Trial) are **localization values only**, keyed by `displayNameKey`. Changing a fantasy name touches only l10n and never any id, save key, or progress.
- Note the **naming migration**: today's persisted `unlocked_chapter_ids` / `chapter_progress` use `chapter_1..chapter_4` to mean *difficulty bands of Chapter 1*. Under the new model those become Chapter 1's *tiers*. Because both are derived and recomputed from `completed` at startup, this is a re-interpretation of transient cache keys, not a data migration (see D).

---

## D. Backward-compatible save migration proposal

**The key structural fact:** In `main()`, `ProgressionController.ensureInitialized()` → `_sync()` calls `AppController.recordProgression(...)` on **every launch**, overwriting `unlocked_level_ids`, `unlocked_chapter_ids`, and `chapter_progress` with values recomputed purely from `completed_level_ids`. Therefore:

- **Durable truth:** `completed_level_ids` (the `rs_NNN` set), `completed_levels_count`, the daily-streak / monetization fields, Free Play stats, and the per-level active snapshots (`runic_sudoku/rs_NNN`).
- **Transient cache (safe to redefine):** `unlocked_level_ids`, `unlocked_chapter_ids`, `chapter_progress`. Rewriting the progression model regenerates these from scratch; there is nothing to "migrate".

**Migration contract for existing Chapter 1 users (no reset, no re-interpretation of durable data):**
1. `completed_level_ids` is read verbatim. `rs_NNN` ids keep their exact meaning; every completed Chapter 1 level stays completed. No id is renamed.
2. On first launch of the Chapter 2 build, the new `CampaignRegistry` is built (c1 from the existing pool asset, c2 gated as configured). `ensureInitialized()` re-derives all unlock/chapter state from `completed_level_ids`, now expressed in the new chapter/tier vocabulary. The stale `chapter_1..chapter_4` entries in the persisted cache are simply overwritten.
3. `progression_version` bumps `1 → 2`. The loader treats `< 2` as "legacy derived cache present; ignore and recompute" (which already happens unconditionally, so the bump is a guard/marker, not a data transform). Persist `2` after the first successful re-derive.
4. An in-progress Chapter 1 active game at `runic_sudoku/rs_NNN` still loads (its snapshot carries its own `grid_size`/`box_shape`, and `RunicSudokuState.fromSnapshot` is board-parametric). Untouched.
5. Chapter 2 is purely additive: new `c2_*` ids, a new c2 pool asset, and new derived rows. No existing key is deleted or rewritten in a lossy way.

**One correctness fix that IS a (tiny) model change, and must ship with the migration:** freeze unlock thresholds (see E) so re-deriving after a future chapter-growth cannot retro-lock a chapter. This changes how the derived set is computed, not what durable data means, so it remains progress-safe.

Result: an existing player opens the Chapter 2 build, sees all Chapter 1 progress intact, Free Play still unlocked if it was, and Chapter 2 appears as new locked/unlocked content per policy.

---

## E. Progression calculation proposal

**What counts.** Chapter completion and next-chapter unlock consider only tiers with `countsTowardProgress == true`. Expert (`isOptionalExpert == true`, `countsTowardProgress == false`) is excluded from both the numerator and the denominator of any chapter's completion percentage, and can never be a prerequisite for unlocking the next chapter.

**Chapter completion.** For chapter X: `coreLevels(X) = union of levels across X's core tiers`; `completed(X) = |completed_level_ids ∩ coreLevels(X)|`; `percent(X) = completed(X) / |coreLevels(X)|`. Expert levels are never in `coreLevels`.

**Next-chapter unlock — frozen, versioned thresholds (fixes must-close #5).** Replace `ceil(liveSize × fraction)` with an **absolute, versioned threshold stored in the chapter's `unlockPolicy`**, e.g. `unlockNextAfter: { coreLevelsCompleted: N }` where `N` is fixed at authoring time (e.g. current behaviour ≈ `ceil(coreCount × 0.5)` snapshotted to a constant). Because the threshold no longer tracks live size:
- Adding core levels to a chapter later **cannot** raise the bar on players who already met it → no retro-locking. Unlock is monotonic.
- `poolVersion` records when a pool grew; unlock thresholds are keyed to a policy version, not to `levels.length`, so already-earned unlocks are stable.

**Unlock is monotonic / never revoked.** Keep the existing "completed levels are always replayable" guarantee. Add the invariant that once `isChapterUnlocked(X)` has been true for a profile it is never recomputed to false by content growth (guaranteed structurally by frozen thresholds; optionally also persist a high-water `unlocked_chapter_ids` union that is only ever added to). Prefer the structural guarantee (frozen thresholds) as the source of truth, with the persisted union as belt-and-suspenders.

**Absolute vs percentage.** Store the gate as an **absolute core-level count** (authoring-time snapshot) rather than a live percentage, precisely so future additions don't move it. Display can still show a percentage; the *gate* is absolute and frozen.

**Cross-chapter ordering.** `c2` unlock policy references `c1` core completion (e.g. "complete N core levels of c1"), evaluated over the registry — never over a single pool's `presentLabels`.

**Daily & Free Play unchanged.** Daily still does not feed campaign progression; Free Play still records only Free Play stats. No change to those independence guarantees.

---

## Scope 6 — Surrounding systems (report only; NOT solved here)

- **Daily Puzzle** (`daily_puzzle.dart`, `dailyFor`): single pool, `FNV(date) % levels.length`, single `active_daily` slot. Constraint for this work: **keep the Chapter 2 pool as a separate asset/pool**; do not merge into the Chapter 1 `levels` array, or daily selection shifts for everyone and `rs_NNN` positional ids move. A board-varying Daily is a separate future design.
- **Free Play** (`free_play_screen.dart`): on-demand generation hardwired to `BoardConfig.sixBySix`; `_freePlayMaxAttempts` 6×6-tuned; single `active_freeplay` slot; `freePlaysBestTimes` keyed by label only. A 9×9 Free Play needs per-board budgets, a board-scoped slot key, and board-scoped best-times. Out of scope.
- **DeepFreePlayCache** (`deep_free_play_cache.dart`): already board-namespaced (`cacheKeyFor`), legacy key auto-cleaned; bundled Deep pool is 6×6-only. A 9×9 Deep needs its own bundled pool asset. Keying already scales.
- **`deep_used_ids` / deep ids** (`deep_pool.dart`): `deep_fp_NNN` bundled + `deep_c_<hash>` cache ids are not board-tagged. Cosmetic today; if 9×9 Deep ships, tag ids by board. Free Play scope.
- **Achievements / statistics**: `completed_levels_count` is a single global lifetime counter (mixes c1+c2 — fine as a stat, unusable as per-chapter %); daily streak and Free Play stats are chapter-agnostic. No per-chapter achievements exist. Adding c2 inflates the global count harmlessly.
- **Localization**: fantasy names are currently hardcoded in `progression.dart` `_displayNames` and `chapter_theme.dart` `_byLabel`; `how_to_play_dialog` templates from the rune count. The design moves fantasy names behind `displayNameKey` (l10n). Additive.
- **Analytics** (`analytics.log` calls): events carry `level_id` / `difficulty`, no `chapterId`/`tierId`. Adding those fields is additive and non-breaking.
- **Bundled assets**: `assets/levels/runic_sudoku_levels.json` (c1, 100 levels), `assets/freeplay/deep_pool.json`, four label-keyed backgrounds. Chapter 2 needs its own pool asset, optional 9×9 art, and the (already-present but unregistered) `elderFutharkNineSet` wired to a theme with `requireSymbolCount(9)`.

---

## Scope 7 — Migration options compared (max three)

| Option | Approach | Files touched | Backward compat | Production code affected | Testing | Risk | Recommendation |
|--------|----------|---------------|-----------------|--------------------------|---------|------|----------------|
| **1. Additive multi-chapter registry** (recommended) | Introduce `ChapterDefinition`/`TierDefinition`/`LevelDefinition` + `CampaignRegistry`; keep `rs_*` and `completed_level_ids` verbatim; c2 as a separate pool asset with explicit ids; freeze unlock thresholds; `progression_version 1→2` as a guard. | `progression.dart` (generalize), new `chapter_registry.dart`, new c2 pool asset, `main.dart` wiring, small `player_profile` derive change. No renames. | **Full.** Durable data unchanged; derived cache recomputed. | Medium — localized to progression layer + startup wiring. | Unit tests for registry resolution, frozen-threshold non-relock, c1 progress preserved across version bump, c2 additive unlock. | **LOW–MEDIUM** | ✅ **Recommended.** Solves all five must-close items with no destructive migration. |
| **2. Reuse the band-chapter model, bolt c2 on as more bands** | Extend `Progression.fromPool` to ingest a second pool and emit `chapter_5..chapter_8` for c2 bands, reusing positional `chapter_N` ids. | `progression.dart`, `level_pool.dart`, `main.dart`. | Fragile — keeps positional ids (A1/A2) and live-size thresholds (A3); overloads "chapter" further. | Low upfront, high latent. | Hard to test the collision/relock cases; they persist. | **HIGH** | ❌ Rejected — perpetuates the two HIGH hazards. |
| **3. Full persistence redesign** (namespaced per-chapter save trees, explicit migration transform of `completed_level_ids`) | Re-key everything under `c1/…`, `c2/…`; write a one-time migrator that rewrites existing keys. | Broad: save layer, profile, snapshot keys, every call site + a migrator. | Requires a real, tested data transform of live user data. | High — touches persistence broadly (explicitly out of scope per stop-condition). | Extensive migration + rollback testing. | **HIGH** | ❌ Rejected — unjustified; the derived-cache property makes it unnecessary. |

---

## F. Exact recommended implementation sequence (for the FUTURE build step — not done now)

1. **Freeze the level pool schema.** Add explicit `level_id` to `LevelDefinition`/`LevelData` and to the pool-file envelope (`schemaVersion`, `chapterId`, `poolVersion`). Backfill Chapter 1's `runic_sudoku_levels.json` with `rs_000…rs_099` equal to today's derived ids (progress-neutral). Make `LevelPool` read explicit ids, falling back to positional only for a `schemaVersion 0` file.
2. **Introduce the static contract** (`ChapterDefinition`, `TierDefinition`, `LevelDefinition`, `CampaignRegistry`) with **no behaviour change**: model Chapter 1 as one chapter whose four core tiers reproduce today's bands, and prove unlock/next/percent outputs are identical for existing saves (golden test).
3. **Freeze unlock thresholds** (E): replace live `ceil(size×0.5)` with versioned absolute counts in `unlockPolicy`; add the non-relock invariant test.
4. **Bump `progression_version 1→2`** with the guard/recompute path; test c1 progress preserved across the bump.
5. **Add Chapter 2 as data** (separate pool asset with explicit `c2_*` ids, Expert tier defined but `availability = disabledUntilCalibrated`, `countsTowardProgress=false`). Wire `main.dart` to build the registry from both chapters.
6. **UI / content enablement** (later, separate tasks): 9×9 level-select for c2, `elderFutharkNineSet` theme wiring + `requireSymbolCount(9)`, c2 backgrounds. Keep Expert unreachable.
7. **Only after 12×12 feasibility + calibration** (separate future work): give Expert a `difficultyLabel`, flip `availability`, keep `countsTowardProgress=false` forever.

Each step is independently reviewable and independently save-safe.

---

## G. Open questions requiring product-owner review

1. **Chapter-unlock gate for Chapter 2.** What exactly unlocks c2 — complete *all* c1 core levels, a fixed absolute count (what number?), or the same `ceil(core×0.5)` snapshotted to a constant? (Must be an absolute frozen number per E.)
2. **Chapter 1 "chapters" rename.** Confirm it's acceptable that today's `chapter_1..chapter_4` (difficulty bands) become Chapter 1's *tiers* in the new vocabulary. It's progress-safe (derived cache), but any external analytics dashboards reading `unlocked_chapter_ids`/`chapter_progress` keys would see new key shapes.
3. **Chapter 1 pool-id backfill.** Approve adding explicit `level_id`s to the shipped `runic_sudoku_levels.json` (recommended hardening) vs. leaving Chapter 1 positional-but-frozen. Backfill is progress-neutral but edits a shipped asset.
4. **Chapter 2 core size and per-tier counts.** How many core levels per tier (c1 is 20/30/30/20 = 100)? This fixes the frozen unlock threshold and the completion denominator.
5. **Completion percentage semantics.** Is chapter % over core levels only (recommended), and should the app show an aggregate campaign % across c1+c2, or per-chapter only?
6. **Expert visibility while disabled.** Should `c2_expert` be invisible, or shown as a locked "coming soon" teaser (Twelvefold Trial) — and confirm it must never appear in any completion %, unlock gate, Daily, or Free Play until calibrated.
7. **Daily/Free Play board policy (future).** Confirm Daily and Free Play stay 6×6-only for now (keeping the single `active_daily`/`active_freeplay` slots valid), so board-scoped slot keys can be deferred to a dedicated task.

---

## Stop

This is Step 1 (investigation + design) only. No production Dart, save data, pools, or Chapter 2 UI were modified; Expert content remains disabled; `DifficultyTuning` untouched; the release branch untouched. Branch `feature/chapter2-data-model-design` holds no code commits (design-only). **Awaiting review before any implementation.**
