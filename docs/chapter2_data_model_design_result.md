# Chapter 2 Fixed-Level Data Model — Design Investigation & Completion

**Status:** Design + static-verification complete (amended). No production Dart, assets, save data, pools, tests, UI, localization, or pubspec were modified. This document is the only change; it is committed on `feature/chapter2-data-model-design`. Not merged. Awaiting review before any implementation.

**Branch:** `feature/chapter2-data-model-design`, created from `feature/chapter-system-inventory` @ `5927573` (the reviewed Batch 1/2 `BoardConfig` foundation). NOT based on any spike branch.

**Inspection basis:** Traced against branch HEAD `4dba564` ("Document Chapter 2 data model investigation"), whose only delta over the approved base `5927573` is this doc (`git show --stat 4dba564` = 1 file, docs only). Every production `lib/` file is therefore byte-identical to the Batch 1/2 foundation. All line numbers cited in Appendices H and I are from that source.

**Amendment log (this pass):**
- Added **Appendix H** — persistence call-chain proof with exact file/function/line evidence (verifies the load-bearing re-derive claim).
- Added **Appendix I** — analytics wiring verification (closes G2 as no-external-risk).
- Added a **6th must-close item** (intra-chapter *tier* unlock) + inventory row **A18**.
- Added **`TierUnlockPolicy`** and a concrete **`ChapterUnlockPolicy`** to the data contract (§B) and the frozen Chapter-1 tier thresholds derived from code (§E).
- Added **§C-bis — Released level-ID immutability & retirement policy** and the **monotonic high-water chapter-unlock** recommendation (§D).
- Rewrote **§G** as resolved product-owner decisions / deferred items / blockers.
- Expanded the **implementation sequence (§F)** with the required golden/verification steps.

**Verdict (unchanged, now proven):** The persistence model is safe to migrate. The only durable campaign truth is `completed_level_ids` plus the per-level active snapshots; all unlock/chapter structure is a transient cache **unconditionally and completely rebuilt** from that set on every launch (proof: Appendix H). A Chapter 2 model that preserves `completed_level_ids` semantics is inherently non-destructive to Chapter 1 progress. Three latent hazards must be fixed as part of the build: (1) positional `rs_NNN` level identity, (2) chapter-unlock thresholds computed from *live* chapter size, and (3) the same live-size hazard on *intra-chapter tier* unlock.

---

## Executive summary (the six must-close items)

1. **Is level ID explicit or positional?** → **Positional.** `rs_NNN` is derived from the entry index in `runic_sudoku_levels.json` (`LevelPool.levelIdForIndex`); the JSON has no `level_id` field (verified: 100 entries, none carry `level_id`). This id is the save-slot key *and* the completion key. Reordering the pool silently remaps all saved progress. Chapter 2 pools MUST carry explicit `level_id`; Chapter 1 is backfilled with explicit ids equal to today's positional mapping (decision G3).
2. **Chapter 1 progress preservation.** → Guaranteed, no reset, no re-interpretation, provided `completed_level_ids` keeps its meaning and derived state is recomputed (proof: Appendix H). The migration does not touch that set.
3. **Active-save separation.** → Campaign active games are keyed per level (`runic_sudoku/rs_NNN`); Chapter 2 uses a disjoint namespace (`c2_*`), so 6×6 and 9×9 active campaign games never share a slot. The single Daily / Free Play slots stay 6×6-only for now (decision G7).
4. **Unlock counts core only.** → Explicit `countsTowardProgress` flag per tier; Expert is excluded from numerator, denominator, and every unlock gate.
5. **Future core levels must not re-lock a chapter.** → The current model violates this: **chapter** unlock threshold = `ceil(size × 0.5)` from *live* size, recomputed each launch (proof: Appendix H, and §E). Fixed by freezing chapter thresholds as versioned absolute counts, plus a monotonic high-water union (§D).
6. **Future core levels must not re-lock a *tier* inside a chapter.** → **NEW.** The same live-size threshold governs intra-chapter tier unlock today (`isChapterUnlocked` over difficulty bands). Growing a tier raises the bar to unlock the *next* tier and can retro-lock it. Fixed by an explicit `TierUnlockPolicy` with frozen absolute counts (§B, §E, decision G8).

---

## A. Current-state inventory table

Risk = impact × likelihood of breaking Chapter 1 saves or Chapter 2 correctness if left unaddressed.

| # | File | Class / function | Current assumption | Why Chapter 2 affects it | Risk |
|---|------|------------------|--------------------|--------------------------|------|
| A1 | `games/runic_sudoku/level_pool.dart` | `LevelPool.levelIdForIndex`, `_puzzleFromEntry` | Stable level id = **array position** (`rs_000`…); pool JSON stores no `level_id`. | Chapter 2 needs stable ids independent of file order; positional ids re-introduce reorder-corruption on a second, growing pool. | **HIGH** |
| A2 | `games/runic_sudoku/progression.dart` | `Progression.fromPool`, `ChapterMeta` | "Chapter" == one **difficulty band** of a single pool (`chapter_1`=Quick … `chapter_4`=Deep); id = `'chapter_$order'` (positional). | Roadmap "Chapter 2" is a different axis. "Chapter" is overloaded; band-chapters and roadmap-chapters collide in id space and in persisted `unlocked_chapter_ids` / `chapter_progress`. | **HIGH** |
| A3 | `games/runic_sudoku/progression.dart` | `thresholdFor`, `isChapterUnlocked` | **Chapter** unlock threshold = `ceil(chapter.size × 0.5)` from **live** size; recomputed each launch. | Adding core levels raises the threshold and can re-lock an unlocked chapter (must-close #5). | **HIGH** |
| A4 | `games/runic_sudoku/progression.dart` | `_displayNames`, `ChapterMeta.displayName` | Display name is **derived from the difficulty label** (Quick→"Quick Runes"). | Chapter 2 fantasy names must be UI-only, decoupled from tier identity and `DifficultyLabel`. | MEDIUM |
| A5 | `core/profile/player_profile.dart` | `PlayerProfile` (`completed_level_ids`, `unlocked_chapter_ids`, `chapter_progress`, `progression_version`) | Flat id sets; chapter progress keyed by `chapter_N`; one global `completed_levels_count`; `progression_version` reserved, unused. | c2 ids extend the flat set safely, but `chapter_progress` keys and the global count cannot express per-chapter core completion. `progression_version` is the migration hook. | MEDIUM |
| A6 | `core/profile/app_controller.dart` | `recordProgression`, `AppController.load` | Persists derived unlock sets; **re-derived from `completed` at every startup** (Appendix H). | Safety net: model changes re-derive cleanly. Must be preserved and made version-aware. | LOW |
| A7 | `games/runic_sudoku/runic_sudoku_snapshot.dart` | `saveKeyFor`, `RunicSudokuSnapshot` | Campaign slot = `runic_sudoku/<levelId>`; Daily/Free Play each **one** shared slot; board identity stored per snapshot. | c2 campaign slots are naturally disjoint. Daily/Free Play single slots stay 6×6-only (G7). | MEDIUM |
| A8 | `games/runic_sudoku/daily_puzzle.dart` + `level_pool.dart` `dailyFor` | `DailyPuzzleSelector.indexForDate` | Daily = `FNV(date) % levels.length` over the **whole single pool**. | Merging c2 into the same `levels` array shifts the daily for everyone *and* moves every `rs_NNN` positional id. Chapter 2 pool must stay **separate**. | **HIGH** (if pools merged) |
| A9 | `games/runic_sudoku/freeplay/deep_free_play_cache.dart` | `cacheKeyFor`, `deep_freeplay_cache_6x6` | Rolling Deep cache already **board-namespaced**; legacy key removed on load; bundled pool 6×6-only. | Good precedent for board-scoped keys; 9×9 Deep needs its own bundled pool. | LOW |
| A10 | `games/runic_sudoku/freeplay/deep_pool.dart` | `deepIdFromGiven` (`deep_c_…`), bundled `deep_fp_NNN` | Deep ids not board-tagged (FNV of givens only). | Cosmetic today (Free Play scope). | LOW |
| A11 | `app/free_play_screen.dart` | `generateFreePlayPuzzle`, `_freePlayMaxAttempts` | On-demand Free Play hardwired to `BoardConfig.sixBySix`; budgets 6×6-tuned; slot `active_freeplay`. | 9×9 Free Play needs per-board budgets + board-scoped slot. Out of scope (G7). | LOW |
| A12 | `core/profile/player_profile.dart` | `freePlaysBestTimes` (keyed by label), `deepUsedIds` | Best times keyed by difficulty label only, not board. | 9×9 Deep best time would overwrite 6×6. Free Play scope (G7). | LOW |
| A13 | `games/runic_sudoku/chapter_theme.dart` | `ChapterBackgrounds._byLabel` | Backgrounds keyed by difficulty label; four 6×6 art assets. | c2 may reuse label→art or want per-chapter art. Additive. | LOW |
| A14 | `core/theme/rune_set.dart` | `elderFutharkNineSet` | 9-rune set exists, order load-bearing, first 6 == 6-set; **not registered / not reachable**. | c2 9×9 needs it wired to a theme + `requireSymbolCount(9)`. Groundwork laid (Batch 2). | LOW |
| A15 | `games/runic_sudoku/runic_sudoku_rules.dart` | `RunicSudokuRules.sixBySix`, `requireSymbolCount` | Rules preset + symbol-count validation tuned to 6×6 (board-parametric ctor exists). | c2 needs a 9×9 rules preset; ctor already takes dims/box. Additive. | LOW |
| A16 | `games/runic_sudoku/solver/difficulty_constants.dart` | `DifficultyTuning` (all constants) | Thresholds derived from **measured 6×6 data**. | Do NOT reuse blindly for 12×12 Expert; 9×9 feasibility already GREEN, no tuning change. Out of scope. | MEDIUM (Expert only) |
| A17 | `main.dart` | startup wiring | Builds exactly one `LevelPool`, one `Progression.fromPool`, one `DeepFreePlayCache`. | c2 requires a multi-chapter registry, not a single pool/progression. | MEDIUM |
| **A18** | `games/runic_sudoku/progression.dart` | `thresholdFor` used by `isChapterUnlocked` for **band→band** gating; `isLevelUnlocked` sequential-within-band | **Intra-chapter tier** unlock = "previous band completed to `ceil(size×0.5)` of live size"; the "previous band" is chosen by **array position** (`chapters[order-2]`). | Under the new model these bands are Chapter 1's *tiers*. Live-size thresholds can retro-lock a tier when a tier grows (must-close #6); positional prerequisite must become an explicit `prerequisiteTierId`. | **HIGH** |

---

## Separation of concepts (the eight identity axes)

Kept independent, per the confirmed principle that `tierId` (stable identity), `difficultyLabel` (generation/calibration profile) and `displayName` (fantasy UI) are three different things. Unlock behaviour is expressed by **policies** (`ChapterUnlockPolicy`, `TierUnlockPolicy`), which are separate again from these identity axes.

| Axis | Meaning | Example (c2) | Persisted? | Never derived from |
|------|---------|--------------|-----------|--------------------|
| `chapterId` | Stable identity of a chapter (board/level-set). | `c2` | Indirectly (in `levelId`) | fantasy name |
| `tierId` | Stable identity of a tier within a chapter. | `quick`,`normal`,`tricky`,`deep`,`expert` | Indirectly (in `levelId`) | fantasy name, `DifficultyLabel`, list position |
| `difficultyLabel` | Generation / calibration profile (`DifficultyLabel` enum). | `deep` | In snapshot / pool JSON | tierId (Expert has none until calibrated) |
| `displayNameKey` | Localization key for fantasy UI name. | `chapter.c2.tier.tricky.name` → "Ritual Chambers" | asset/loc only | identity |
| `boardConfig` | Board identity (dims, box, runeCount). | 9×9 / 3×3 / 9 | In pool + snapshot JSON | tierId |
| `countsTowardProgress` | Whether a tier's levels count to chapter completion / next-chapter unlock. | `true` core, `false` expert | In tier definition | — |
| `isOptionalExpert` | Marks the optional, gated Expert tier. | `true` only for `expert` | In tier definition | — |
| `levelId` / namespace | Stable, explicit per-level id. | `c2_tricky_007` | **Yes — durable** | array position |

Critical rule: **`levelId` is not `chapterId`, is not `tierId`, is not `difficultyLabel`, is not the fantasy name, and is not derived from list position.** It is an opaque, explicitly-stored string; identity is read from the level's stored `chapterId`/`tierId`, never parsed from the string and never inferred from array index.

---

## B. Proposed minimum data contract (design only — pseudocode, not implementation)

Only abstractions that solve a concrete current requirement are introduced.

```text
// ---- Static definitions (code + bundled asset; NOT player data) ----

ChapterDefinition {
  chapterId            : String        // 'c1', 'c2'         — stable, opaque
  order                : int           // 1, 2               — display/sequence only
  displayNameKey       : String        // loc key; fantasy name lives in l10n
  coreBoardConfig      : BoardConfig    // c1: 6x6/2x3/6, c2: 9x9/3x3/9
  tiers                : List<TierDefinition>
  unlockPolicy         : ChapterUnlockPolicy   // when THIS whole chapter opens
}

TierDefinition {
  tierId               : String        // 'quick'|'normal'|'tricky'|'deep'|'expert'
  displayNameKey       : String        // fantasy name loc key (UI only)
  difficultyLabel      : DifficultyLabel?   // gen/calibration profile;
                                            // NULL for 'expert' until 12x12 calibrated
  boardConfig          : BoardConfig    // == chapter.coreBoardConfig; Expert -> 12x12/4x3/12
  countsTowardProgress : bool          // core = true; expert = false
  isOptionalExpert     : bool          // true only for the Expert tier
  levelNamespace       : String        // 'c2_quick' -> ids 'c2_quick_001', ...
  availability         : TierAvailability   // enabled | disabledUntilCalibrated
  unlockPolicy         : TierUnlockPolicy   // when THIS tier opens inside its chapter
}

// NEW — when a whole roadmap chapter unlocks. Absolute, frozen, versioned.
ChapterUnlockPolicy {
  type                    : initiallyUnlocked | completedCoreCountInChapter
  prerequisiteChapterId   : String?    // e.g. 'c1'  (null for the first chapter)
  coreLevelsRequired      : int?       // FROZEN absolute count; counts ONLY
                                       //   countsTowardProgress==true levels of the prereq.
  policyVersion           : int        // bump only to intentionally change the gate
}
// c1.unlockPolicy = { type: initiallyUnlocked, policyVersion: 1 }
// c2.unlockPolicy = { type: completedCoreCountInChapter,
//                     prerequisiteChapterId: 'c1', coreLevelsRequired: 70, policyVersion: 1 }
//   (decision G1; c1 has 100 core levels, so the gate is 70/100. Expert is irrelevant to it.)

// NEW — when a tier unlocks INSIDE its chapter. Absolute, frozen, versioned.
// Replaces today's live-size band gating (A18). No gate uses list position or a
// live percentage of pool size.
TierUnlockPolicy {
  type                    : initiallyUnlocked | completedCountInTier | disabled
  prerequisiteTierId      : String?    // explicit; NOT chapters[order-2]
  completedLevelsRequired : int?       // FROZEN absolute count (snapshot, not % of live size)
  policyVersion           : int        // bump only to intentionally change the gate
}
// 'disabled' => tier is unreachable regardless of any other condition (Expert while gated).

LevelDefinition {          // one bundled puzzle (from the chapter's pool asset)
  levelId              : String        // 'c2_tricky_007' — EXPLICIT in JSON, durable, opaque
  chapterId            : String        // 'c2'  (stored, not parsed from levelId)
  tierId               : String        // 'tricky'
  levelOrder           : int           // authored order WITHIN the tier (sequence, not identity)
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
  poolVersion          : int           // bump when levels added/changed
  levels               : List<LevelDefinition>   // each with explicit levelId + levelOrder
}

// ---- Player data (persisted; extends the existing PlayerProfile) ----

// completed_level_ids stays a flat Set<String> of opaque levelIds (rs_* AND c2_*).
// Chapter/tier completion is DERIVED by resolving each completed id through the
// registry, so no new per-chapter persisted counters can drift.
//
// unlocked_chapter_ids becomes MONOTONIC high-water state (union-only; never shrinks) —
// see §D. Level unlocks and per-chapter/-tier progress stay pure-derived caches.
//
// Derived (recomputed every launch), illustrative shape:
//   completionByChapter: { 'c1': {core: <done>/100}, 'c2': {core: <done>/<c2 core total>} }
//   (Expert never contributes to numerator or denominator.)
```

The registry that ties it together (built once at startup, replaces the single `Progression.fromPool`):

```text
CampaignRegistry {
  chapters            : List<ChapterDefinition>          // c1, c2 (Expert tier gated off)
  levelsById          : Map<String, LevelDefinition>     // union across all chapter pools
  chapterOf(levelId)  -> ChapterDefinition
  tierOf(levelId)     -> TierDefinition
  // Progression queries (chapter unlock, tier unlock, next, %) operate over this
  // registry + completed set + the frozen policies. No query reads array position.
}
```

---

## C. Stable ID and namespace rules

**Level ids (durable).**
- Chapter 1 keeps its existing ids **exactly**: `rs_000 … rs_099`. Never renamed (they are live save keys).
- Chapter 2 core levels: `c2_<tier>_<NNN>` — `c2_quick_001`, `c2_normal_001`, `c2_tricky_001`, `c2_deep_001`.
- Chapter 2 Expert (future, gated): `c2_expert_001` in its own namespace, so a 12×12 level can never collide with a 9×9 `c2_deep_*` id.
- Ids are **stored explicitly** in every pool file and **treated as opaque**. The `c2_tier_NNN` shape is human-readability only; identity is the stored `chapterId`/`tierId`, never parsed from the string.

**Save-slot keys (durable).**
- Campaign active game: `runic_sudoku/<levelId>` — unchanged. `c2_*` ids are disjoint from `rs_*`; no collision, no 6×6/9×9 ambiguity for campaign.
- Profile: `app/profile` — unchanged.
- Daily / Free Play single slots (`runic_sudoku/active_daily`, `runic_sudoku/active_freeplay`): unchanged; stay 6×6-only (G7). A board-varying variant (board token in the key, mirroring `cacheKeyFor(board)`) is a separate future task.
- Deep rolling cache: already `deep_freeplay_cache_<boardToken>` — scales unchanged.

**Chapter / tier ids (identity, not display).**
- `chapterId ∈ {c1, c2}`, `tierId ∈ {quick, normal, tricky, deep, expert}` — stable, opaque.
- Fantasy names (Opening Seals, Woven Runes, Ritual Chambers, Arcane Grid, Twelvefold Trial) are **localization values only**, keyed by `displayNameKey`. Renaming touches only l10n, never any id/save key/progress.
- Vocabulary migration: today's `chapter_1..chapter_4` (difficulty bands) become Chapter 1's *tiers*. Because these live only in the derived cache (Appendix H) and never leave the device (Appendix I), this is a re-interpretation of transient keys, not a data migration.

---

## C-bis. Released level-ID immutability & retirement policy

**Invariant — released level IDs are permanent.** Once a `levelId` has shipped in a released build:
- It is **never renamed**.
- It is **never reused** for a different puzzle.
- It is **never reassigned** to another chapter or tier.
- **Pool order never determines identity** (identity is the explicit stored id; `levelOrder` is sequence only).
- New content is **append-only** under **new** ids.
- Every id already present in a player's `completed_level_ids` must always remain **resolvable**, or be safely preserved as a historical id (see below). A completed id that no longer resolves must never be silently dropped.

**Future emergency retirement / tombstone policy (NOT implemented here — flagged for a dedicated reviewed design).** If a shipped puzzle must ever be pulled from play, its id **must remain reserved and must never be reused**. A `retired`/tombstone marker must NOT be introduced casually; a reviewed policy must first define all four semantics:
1. **Historical completion credit** — a player who already completed the level keeps the credit (their `completed_level_ids` entry stays valid and counted for *them*).
2. **Current completion denominator** — whether the retired level still counts in the "N core levels" denominator for players who never completed it / for new installs (affects displayed % and any gate that counts core levels).
3. **Replay availability** — whether the level can still be opened, or only shows as historically-completed.
4. **Unlock monotonicity** — retiring a level must never drop any player below a chapter/tier unlock threshold they already met (this is exactly what the high-water union in §D protects against).

Until that policy exists, the rule is simply: **do not remove or renumber a released level.** Additions only.

---

## D. Backward-compatible save migration proposal

**Structural fact (proven in Appendix H):** In `main()`, `ProgressionController.ensureInitialized()` → `_sync()` → `AppController.recordProgression(...)` runs unconditionally on every launch and **completely replaces** (assignment, not merge) `unlocked_level_ids`, `unlocked_chapter_ids`, and `chapter_progress` with values recomputed purely from `completed_level_ids`. Therefore:

- **Durable source-of-truth:** `completed_level_ids` (the `rs_NNN` set), `completed_levels_count`, daily-streak / monetization fields, Free Play stats, `deep_used_ids`, and the per-level active snapshots (`runic_sudoku/rs_NNN`, `active_daily`, `active_freeplay`). Mutated only by explicit gameplay events, never by the startup re-derive.
- **Transient derived cache (safe to redefine):** `unlocked_level_ids`, `chapter_progress`, `last_played_level_id`, and (today) `unlocked_chapter_ids`. Rebuilt from scratch each launch.
- **High-water / monotonic state:** **none today** (Appendix H confirms `unlocked_chapter_ids` is a pure replace). Introduced by this design for roadmap-chapter unlocks only (below).

**Migration contract for existing Chapter 1 users (no reset, no re-interpretation of durable data):**
1. `completed_level_ids` is read verbatim; `rs_NNN` ids keep their exact meaning. No id renamed.
2. On first launch of the Chapter 2 build, the `CampaignRegistry` is built (c1 from the existing pool, c2 gated as configured). `ensureInitialized()` re-derives all unlock/chapter state from `completed_level_ids` in the new chapter/tier vocabulary; stale `chapter_1..chapter_4` cache entries are overwritten.
3. `progression_version` bumps `1 → 2` as a guard/marker (the re-derive already happens unconditionally, so there is no data transform). Persist `2` after the first successful re-derive.
4. An in-progress Chapter 1 active game at `runic_sudoku/rs_NNN` still loads (its snapshot carries its own `grid_size`/`box_shape`; `RunicSudokuState.fromSnapshot` is board-parametric). Untouched.
5. Chapter 2 is purely additive: new `c2_*` ids, a new pool asset, new derived rows. No existing key is deleted or lossily rewritten.

**Correctness fixes that ship with the migration (change how the derived set is computed, not what durable data means):**
- **Freeze chapter thresholds and tier thresholds** (§E) so re-deriving after future content growth cannot retro-lock a chapter (#5) or a tier (#6).
- **Monotonic high-water union for roadmap-chapter unlocks.** Change `recordProgression`'s handling of the chapter-unlock field from replace to union: `persistedUnlockedChapterIds = persistedUnlockedChapterIds ∪ newlyDerivedChapterUnlocks`. 
  - *Why in addition to frozen thresholds?* Frozen thresholds prevent the common relock cause (chapter growth), but the union also defends against causes they don't cover: an emergency level retirement lowering a player's core count below a gate, a bugged/short pool asset, or a deliberate future `policyVersion` bump that raises a gate. An already-earned roadmap chapter is the highest-value, hardest-to-earn boundary, so it gets belt-and-suspenders.
  - *Persistence implication:* `unlocked_chapter_ids` stops being a pure cache and becomes **semi-durable, add-only** state (it never shrinks). The loader/`recordProgression` must union rather than assign for that one field. Trade-off accepted: a mistakenly-granted chapter also cannot be revoked — we err toward not punishing the player.
  - *Scope:* apply the union to **roadmap-chapter** unlocks only. Tier and level unlocks rely on frozen thresholds alone (lower stakes; a monotonic tier union would complicate clean re-derivation). Can be extended later if needed.

Result: an existing player opens the Chapter 2 build, sees all Chapter 1 progress intact, Free Play still unlocked if it was, and Chapter 2 appears as new locked/unlocked content per policy.

---

## E. Progression calculation proposal

**What counts.** Chapter completion, next-chapter unlock, and tier unlock consider only tiers with `countsTowardProgress == true`. Expert (`isOptionalExpert == true`, `countsTowardProgress == false`, `availability == disabledUntilCalibrated`) is excluded from every numerator, denominator, and gate, and can never be a prerequisite for anything.

**Chapter completion.** For chapter X: `coreLevels(X) = ∪ levels across X's core tiers`; `completed(X) = |completed_level_ids ∩ coreLevels(X)|`; `percent(X) = completed(X) / |coreLevels(X)|`. Expert levels are never in `coreLevels`.

**Chapter unlock (frozen, versioned — fixes #5).** `ChapterUnlockPolicy` with an **absolute** `coreLevelsRequired`, not a live percentage. Concrete decisions:
- `c1`: `initiallyUnlocked`.
- `c2`: unlocks at **70 completed c1 core levels** (decision G1; c1 core total = 100, verified 20+30+30+20). Absolute, frozen, `policyVersion: 1`. Expert is irrelevant to this gate.
Plus the monotonic union (§D) so an earned chapter is never revoked.

**Tier unlock (frozen, versioned — fixes #6).** `TierUnlockPolicy` per tier, with an **explicit** `prerequisiteTierId` and an **absolute** `completedLevelsRequired`. No gate reads array position or live pool size.

Chapter 1 tiers must reproduce today's behaviour **exactly**. Traced from code (`progression.dart`): `isChapterUnlocked` gates band N on `completedInChapter(band N-1) >= thresholdFor(band N-1)`, where `thresholdFor = ceil(size × chapterUnlockFraction)` and `chapterUnlockFraction = 0.5`. With the verified Chapter-1 pool counts (Quick 20 / Normal 30 / Tricky 30 / Deep 20), today's thresholds are:

| Tier (c1) | Current rule | Frozen `TierUnlockPolicy` (reproduces today) |
|-----------|--------------|----------------------------------------------|
| quick | order 1 → always unlocked | `{ type: initiallyUnlocked, policyVersion: 1 }` |
| normal | Quick completed ≥ `ceil(20×0.5)` = **10** | `{ type: completedCountInTier, prerequisiteTierId: quick, completedLevelsRequired: 10, policyVersion: 1 }` |
| tricky | Normal completed ≥ `ceil(30×0.5)` = **15** | `{ type: completedCountInTier, prerequisiteTierId: normal, completedLevelsRequired: 15, policyVersion: 1 }` |
| deep | Tricky completed ≥ `ceil(30×0.5)` = **15** | `{ type: completedCountInTier, prerequisiteTierId: tricky, completedLevelsRequired: 15, policyVersion: 1 }` |

These numbers (10 / 15 / 15) are the *snapshot* of today's computed thresholds, not invented replacements. (Free Play unlock today uses the same Quick ≥ 10 gate — `isFreePlayUnlocked`; it is preserved unchanged.) Within a tier, levels stay sequentially gated (a tier's first level opens when the tier unlocks; each subsequent level opens when the prior one is completed) — order comes from the authored `levelOrder`, identity from the explicit `levelId`.

Chapter 2 tiers: **four sequential core tiers** (quick → normal → tricky → deep), each a frozen `completedCountInTier` on its predecessor, `policyVersion: 1`. Exact `completedLevelsRequired` values are **pending calibration** (decision G4) — the structure is fixed now; the numbers are filled once c2 tier sizes are approved. Expert: independent optional `TierUnlockPolicy`, `type: disabled` while gated (unreachable), and even once enabled it **never** gates Chapter 3 and never counts toward core completion.

**Absolute vs percentage.** Every gate (chapter and tier) is stored as a **frozen absolute count**; display may still show a percentage, but the gate is absolute so future additions never move it.

**Daily & Free Play unchanged.** Daily still does not feed campaign progression; Free Play still records only Free Play stats.

---

## Scope 6 — Surrounding systems (report only; NOT solved here)

- **Daily Puzzle** (`daily_puzzle.dart`, `dailyFor`): single pool, `FNV(date) % levels.length`, single `active_daily` slot. Constraint: **keep the Chapter 2 pool a separate asset/pool**; do not merge into the Chapter 1 `levels` array. Stays 6×6-only (G7).
- **Free Play** (`free_play_screen.dart`): on-demand generation hardwired to `BoardConfig.sixBySix`; `_freePlayMaxAttempts` 6×6-tuned; single `active_freeplay` slot; `freePlaysBestTimes` keyed by label only. Stays 6×6-only (G7); board-scoped variant is a separate future task.
- **DeepFreePlayCache** (`deep_free_play_cache.dart`): already board-namespaced; bundled Deep pool 6×6-only. A 9×9 Deep needs its own bundled pool. Keying scales.
- **`deep_used_ids` / deep ids** (`deep_pool.dart`): `deep_fp_NNN` + `deep_c_<hash>` not board-tagged. Cosmetic; Free Play scope.
- **Achievements / statistics**: `completed_levels_count` is a single global lifetime counter (fine as a stat, unusable as per-chapter %); daily streak + Free Play stats are chapter-agnostic. Adding c2 inflates the global count harmlessly.
- **Localization**: fantasy names are currently hardcoded in `progression.dart` `_displayNames` and `chapter_theme.dart` `_byLabel`; `how_to_play_dialog` templates from the rune count. The design moves fantasy names behind `displayNameKey` (l10n). Additive.
- **Analytics**: no product-analytics backend is wired (proof: Appendix I). Progression events go only to a no-op sink and never leave the device; adding `chapterId`/`tierId` to events later is additive and non-breaking.
- **Bundled assets**: `assets/levels/runic_sudoku_levels.json` (c1, 100 levels), `assets/freeplay/deep_pool.json`, four label-keyed backgrounds. Chapter 2 needs its own pool asset, optional 9×9 art, and the (present but unregistered) `elderFutharkNineSet` wired to a theme with `requireSymbolCount(9)`.

---

## Scope 7 — Migration options compared (max three)

| Option | Approach | Files touched | Backward compat | Production code | Testing | Risk | Recommendation |
|--------|----------|---------------|-----------------|-----------------|---------|------|----------------|
| **1. Additive multi-chapter registry** (recommended) | `ChapterDefinition`/`TierDefinition`/`LevelDefinition` + `CampaignRegistry`; keep `rs_*` and `completed_level_ids` verbatim; c2 a separate pool asset with explicit ids; freeze chapter + tier thresholds; monotonic chapter union; `progression_version 1→2` guard. | `progression.dart` (generalize), new `chapter_registry.dart`, new c2 pool asset, `main.dart` wiring, small `player_profile`/`recordProgression` change (chapter-union). No renames. | **Full.** Durable data unchanged; derived cache recomputed; chapter unlocks add-only. | Medium — localized to progression layer + startup wiring. | Golden + invariant tests (see §F). | **LOW–MEDIUM** | ✅ **Recommended.** Solves all six must-close items with no destructive migration. |
| **2. Reuse the band-chapter model, bolt c2 on as more bands** | Extend `Progression.fromPool` to ingest a second pool and emit `chapter_5..chapter_8`, reusing positional `chapter_N` ids. | `progression.dart`, `level_pool.dart`, `main.dart`. | Fragile — keeps positional ids (A1/A2), live-size chapter thresholds (A3) and tier thresholds (A18). | Low upfront, high latent. | Collision/relock cases persist and resist testing. | **HIGH** | ❌ Rejected — perpetuates three HIGH hazards. |
| **3. Full persistence redesign** (per-chapter save trees, explicit transform of `completed_level_ids`) | Re-key everything under `c1/…`, `c2/…`; one-time migrator rewriting live keys. | Broad: save layer, profile, snapshot keys, every call site + migrator. | Requires a tested transform of live user data. | High — broad persistence rewrite (explicitly out of scope). | Extensive migration + rollback testing. | **HIGH** | ❌ Rejected — unjustified; the derived-cache property (Appendix H) makes it unnecessary. |

---

## F. Exact recommended implementation sequence (for the FUTURE build step — not done now)

1. **Freeze the pool schema.** Add explicit `level_id` + `level_order` to `LevelData`/`LevelDefinition` and the pool envelope (`schemaVersion`, `chapterId`, `poolVersion`). Make `LevelPool` read explicit ids, falling back to positional only for a `schemaVersion 0` file.
2. **Chapter 1 ID backfill + golden verification (decision G3).** Backfill `runic_sudoku_levels.json` with explicit `rs_000…rs_099` **exactly equal to today's positional mapping**, no reordering. Ship a **golden mapping test that runs before and after the asset edit** and asserts index→id is byte-identical.
3. **Introduce the static contract** (`ChapterDefinition`, `TierDefinition`, `LevelDefinition`, `CampaignRegistry`, `ChapterUnlockPolicy`, `TierUnlockPolicy`) with **no behaviour change**: model Chapter 1 as one chapter whose four core tiers reproduce today's bands. Ship a **Chapter-1 tier-unlock compatibility golden test** proving unlock/next/percent outputs are identical for existing saves (boundaries: Quick 9 vs 10, Normal 14 vs 15, Tricky 14 vs 15).
4. **Freeze chapter thresholds** (absolute `coreLevelsRequired`, `policyVersion`) + **freeze tier thresholds** (absolute `completedLevelsRequired`, explicit `prerequisiteTierId`, `policyVersion`). Add non-relock invariant tests: growing a tier/chapter does not raise an existing gate.
5. **Monotonic unlock behaviour.** Change `recordProgression` to union (not replace) `unlocked_chapter_ids`; test that an earned chapter survives a simulated core-count drop / gate bump.
6. **`progression_version` migration.** Bump `1 → 2` with the guard/recompute path; test Chapter 1 progress preserved across the bump.
7. **Add Chapter 2 as data** (separate pool asset, explicit `c2_*` ids, four core tiers with pending thresholds, Expert defined but `disabledUntilCalibrated` / `countsTowardProgress=false`). Wire `main.dart` to build the registry from both chapters.
8. **UI / content enablement** (later, separate tasks): 9×9 level-select for c2, `elderFutharkNineSet` theme wiring + `requireSymbolCount(9)`, c2 backgrounds. Expert stays hidden.
9. **Only after 12×12 feasibility + calibration** (separate future work): give Expert a `difficultyLabel`, flip `availability`, keep `countsTowardProgress=false` and out of every gate forever.

Future tests the design requires (specified, not implemented now): Chapter-1 tier-unlock golden; pool growth does not raise an existing tier threshold; completing Expert does not unlock the next chapter; Expert not required for 100% core completion; disabled Expert remains unreachable; tier reordering does not change tier identity or unlock semantics; Chapter-1 id-backfill golden mapping (before/after).

**Next implementation priority:** the **Chapter 2 fixed-level architecture** (steps 1–7 above). Daily, Free Play, and 12×12 Expert implementation remain out of scope.

---

## G. Product-owner decisions (resolved), deferred items, and blockers

**Resolved decisions**

- **G1 — Chapter 2 unlock gate.** Chapter 2 unlocks after **70 completed Chapter 1 core levels**. Absolute, frozen threshold (not a computed percentage); Expert content is irrelevant to the gate. Encoded as `c2.unlockPolicy = { completedCoreCountInChapter, prerequisiteChapterId: c1, coreLevelsRequired: 70, policyVersion: 1 }`.
- **G2 — Chapter 1 vocabulary.** Today's `chapter_1..chapter_4` difficulty bands become **tiers inside roadmap Chapter 1**, preserving current unlock behaviour exactly (§E, 10/15/15). Analytics verified (Appendix I): no product-analytics backend is wired and these keys never leave the device, so **no external consumer depends on the old key shapes → external-integration risk NONE/LOW**. Internal persisted-key migration remains backward-safe by construction (derived cache).
- **G3 — Chapter 1 explicit ID backfill.** **Approved.** Add explicit `rs_000…rs_099` to the shipped pool during implementation, exactly matching today's positional mapping; no reordering; a golden mapping test required before and after the asset change (§F step 2).
- **G5 — Completion display.** Show **per-chapter core completion**, Expert excluded. **No aggregate c1+c2 campaign percentage** in the first implementation.
- **G6 — Disabled Expert.** **Hidden completely** while disabled — no "Coming Soon" teaser. Absent from progress, Daily, Free Play, unlock gates, analytics progression, and completion denominators. Becomes visible only after 12×12 feasibility, calibration, and real content exist.
- **G7 — Daily & Free Play.** Remain **6×6-only** during the first Chapter 2 fixed-level implementation. Board-scoped Daily/Free Play saves, stats, caches, and UI are separate future tasks. The 9×9 Free Play feasibility results remain valid groundwork but do not change implementation priority.
- **G8 — Intra-chapter tier unlocks.** Add an explicit **`TierUnlockPolicy`**. Chapter 1 reproduces current behaviour exactly (10/15/15). Chapter 2 has **four sequential core tiers**, all gated by **frozen absolute counts**. Expert has an independent optional policy and **never gates Chapter 3**.

**Intentionally deferred**

- **G4 — Chapter 2 per-tier sizes.** Undecided by design. Do **not** copy 20/30/30/20. Decide only after a calibrated 9×9 fixed-level sample pool and player-time review. The data model already supports **arbitrary per-tier counts**; the c2 `TierUnlockPolicy.completedLevelsRequired` values and the c2 core denominator stay `TBD` until then.
- **Board-scoped Daily/Free Play** (keys, stats, caches, UI) — deferred with G7.
- **12×12 Expert** difficulty label, calibration, availability flip, and content — deferred until feasibility + calibration.
- **Emergency level retirement / tombstone semantics** (§C-bis) — a dedicated reviewed policy, only if/when a shipped level ever needs pulling.

**Open blockers before implementation can start**

- **G4 numbers** gate the *content* of Chapter 2 (tier sizes, c2 unlock denominators, Expert eventual threshold), but **not** the architecture: steps 1–6 of §F (schema freeze, id backfill, registry, frozen policies, monotonic union, version bump) can proceed and be fully tested with Chapter 1 alone. Chapter 2 data (step 7) is blocked on G4. No other blockers identified.

---

## Appendix H — Persistence call-chain proof

Goal: prove the load-bearing claim that the derived progression cache is **unconditionally and completely** rebuilt from `completed_level_ids` on every normal launch, so redefining the progression model cannot corrupt Chapter 1 progress. Evidence is from branch HEAD `4dba564` (production `lib/` identical to approved base `5927573`).

**Step 1 — startup entry (`lib/main.dart`, `main()`), unconditional, every launch.** Executed top-to-bottom before `runApp` (which is the last statement of `main`):
- L60 `final levelPool = await LevelPool.loadFromAsset();`
- L62 `final appController = await AppController.load(saveService: save, analytics: analytics);`
- L63 `await appController.onSessionStart();`
- L67 `final progression = Progression.fromPool(levelPool);`
- L68–69 `final progressionController = ProgressionController(app: appController, progression: progression);`
- **L70 `await progressionController.ensureInitialized();`**
No `if`/guard wraps L70; it runs on every normal launch. (Only Firebase init at the top and ads/billing later sit in `try/catch`; the progression wiring does not.)

**Step 2 — `lib/games/runic_sudoku/progression_controller.dart`.**
- L55 `Future<void> ensureInitialized() => _sync();` — unconditional delegate, no guard.
- L57–65 `_sync({String? lastPlayed})`:
  ```
  final completed = app.completedLevelIds;                    // L58
  return app.recordProgression(
    unlockedLevels:  progression.computeUnlockedLevels(completed),   // L60 — fresh
    unlockedChapters: progression.computeUnlockedChapters(completed),// L61 — fresh
    chapterProgress: progression.chapterProgress(completed),         // L62 — fresh
    lastPlayedLevelId: lastPlayed,                                   // L63 — null at startup
  );
  ```
  No early return, no cache guard, no `try/catch`. All three collections are recomputed from `completed` on every call. (`computeUnlockedLevels`, L173–186, starts from an empty set each call and unions `completed` back in — a full rebuild, not cross-launch accumulation.)

**Step 3 — `lib/core/profile/app_controller.dart`, `recordProgression` (L256–270).**
```
profile.unlockedLevelIds  = unlockedLevels;    // L262  REPLACE (assignment)
profile.unlockedChapterIds = unlockedChapters; // L263  REPLACE
profile.chapterProgress   = chapterProgress;   // L264  REPLACE
if (lastPlayedLevelId != null) profile.lastPlayedLevelId = lastPlayedLevelId; // L265-267
await _save(SaveTriggerType.appPause);         // L268
notifyListeners();                             // L269
```
These are whole-collection **assignments** — the derived collections are completely replaced, not merged/unioned. `_save` (L281–282) → `saveService.save(profile, …)` → `LocalSaveRepository.save` serializes the **entire** profile via `jsonEncode(profile.toJson())` and writes it under the single key `app/profile` (`SharedPreferences.setString`), so the persisted profile is replaced atomically at the key level.

**Data-class classification.**
- **Durable source-of-truth:** `completed_level_ids` and `completed_levels_count` are mutated **only** in `onLevelCompleted` (L120 `profile.completedLevelIds.add(levelId)`, L121 `completedLevelsCount++`), never in `recordProgression`. Likewise Free Play stats (`onFreePlayCompleted`), daily streak, monetization counters, `deep_used_ids`, and the per-level active snapshots (separate keys `runic_sudoku/<levelId>`). The startup re-derive never writes these values (it only re-serializes them unchanged).
- **Transient derived cache:** `unlocked_level_ids`, `chapter_progress`, `last_played_level_id`, and today `unlocked_chapter_ids` — fully rebuilt each launch.
- **High-water / monotonic state:** **none.** `unlocked_chapter_ids` is a pure replace (L263); there is no union/high-water anywhere. (This is why §D introduces one.)

**Failure / partial-write analysis.** `recordProgression` mutates the in-memory `profile.*` derived fields (L262–264) **before** the `await _save` (L268). If `_save` throws (e.g. `setString` failure), the exception propagates `recordProgression → _sync → ensureInitialized → main()` (L70 is not wrapped), so `runApp` would not be reached — the app fails to start rather than starting with corrupt state. Crucially, `recordProgression` never touches `completed_level_ids`, and `toJson()` writes the whole profile, so even a failed derived-cache save cannot lose or alter the durable completed set; the worst case is a stale derived cache that is recomputed on the next launch anyway. There is **no code path in which the app runs without the re-derive having executed** (it precedes `runApp`).

**Conclusion.** The report's claim holds, with one useful precision: the re-derive **completely replaces the derived cache** (`unlocked_*`, `chapter_progress`) but **does not touch `completed_level_ids`** (the durable truth) — which is exactly what makes a progression-model change safe. Stop-condition **not** triggered; the migration verdict stands and is strengthened.

---

## Appendix I — Analytics wiring verification

Goal: determine whether any external consumer can depend on the persisted `chapter_progress` / `unlocked_chapter_ids` key shapes (closes G2).

**Evidence (branch HEAD `4dba564`).**
1. **`firebase_analytics` is NOT a dependency.** `pubspec.yaml` declares `shared_preferences`, `firebase_core ^3.8.0`, `firebase_crashlytics ^4.2.0`, `google_mobile_ads ^5.2.0`, `in_app_purchase ^3.2.0` — no analytics package. `pubspec.lock` contains only `firebase_core`, `firebase_core_platform_interface`, `firebase_core_web`, `firebase_crashlytics`, `firebase_crashlytics_platform_interface` — **no `firebase_analytics`** entry.
2. **No Firebase Analytics instance is created.** A search for `FirebaseAnalytics` across `lib/` returns nothing.
3. **Production wires `NoopAnalyticsService`** (`lib/main.dart` L58: `const analytics = NoopAnalyticsService();`, passed to `AppController.load` L62 and `AppServices` L115). The **only** `AnalyticsService` implementation in the codebase is `NoopAnalyticsService` (`lib/core/analytics/noop_analytics_service.dart`); its `logEvent` only calls `developer.log(...)` in debug (`echoToConsole` default `true`) and otherwise does nothing.
4. **Campaign progression events never leave the device.** The only progression-related `analytics.log` calls are `profile_level_completed` (`app_controller.dart` L125; params `level_id`, `is_daily`, `completed_levels_count`, `daily_streak`) and `level_complete` (`runic_sudoku_controller.dart` L285; params `level_id`, `mistakes`, `hints`, `elapsed_ms`). Both flow only to the no-op sink; **neither event even includes** `chapter_progress` or `unlocked_chapter_ids`.
5. **No external dashboard can currently depend on the old persisted key names.** Those keys live only in local `SharedPreferences` (`app/profile`) and are never transmitted.
6. **Firebase Crashlytics is present but is not product analytics.** `firebase_crashlytics` is wired in `main.dart` for uncaught-error/crash reporting (`FlutterError.onError`, `PlatformDispatcher.instance.onError`). It captures error/stack traces, not gameplay/progression events or persisted key names — a separate concern from product analytics.

**Conclusion.** No product-analytics backend is wired. **G2 external-integration risk = NONE/LOW.** The Chapter-1 → tier vocabulary change and the persisted-key redefinition are safe from an external-consumer standpoint. Internal persisted-key migration must still be backward-safe — and is, because the affected keys are a device-local derived cache (Appendix H). Adding `firebase_analytics` is out of scope and not done.

---

## Stop

Documentation + static-verification task complete. No production Dart, assets, save data, pools, tests, UI, localization, or pubspec were modified. Expert content remains disabled; `DifficultyTuning` untouched; the release branch untouched. Only this document changed, committed on `feature/chapter2-data-model-design`. **Not merged; awaiting review.** Recommended next task: implement the Chapter 2 fixed-level architecture (§F steps 1–7), starting with the schema freeze and Chapter-1 id-backfill golden verification.
