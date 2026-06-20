# Runic Sudoku — Phase 3.59: Per-Chapter Backgrounds / Theme Polish

Adds stylistic per-chapter background art behind the campaign list and the
active puzzle, with a dark readability overlay. Purely visual — no gameplay,
generator, solver, or progression-rule changes.

> **Verification status (honest).** The sandbox has **no Dart SDK**, so I could
> not run `flutter test` / `flutter analyze`. The background→chapter mapping is a
> pure const map (test added). Asset files are in place and inspected
> (dimensions/sizes). The visual checks (correct background per chapter, overlay
> readability on a small screen) need a device/emulator run.

## 1. Implementation plan

- One **centralized** mapping (`ChapterBackgrounds`): difficulty label → bundled
  background asset, plus a neutral fallback. No widget hardcodes a path.
- One reusable widget (`ChapterBackground`): stacks `background image → dark
  overlay (adjustable opacity) → child`, with a safe fallback if an asset is
  missing.
- Apply it: the **puzzle screen** uses the background of the level's chapter
  (overlay 0.5); the **campaign list** spans all chapters, so it uses the neutral
  background (overlay 0.6). The **daily puzzle** is a real pool level, so it
  automatically uses its source chapter's background — no special case, and it
  never affects progression.

## 2. Changed / added files

**Added:** `lib/games/runic_sudoku/chapter_theme.dart` (mapping + widget);
`assets/backgrounds/default_rune_bg.png` (generated neutral); this file;
`test/chapter_background_test.dart`.

**Used (already provided by you):** `assets/backgrounds/quick_runes_bg.png`,
`normal_seals_bg.png`, `tricky_glyphs_bg.png`, `deep_chambers_bg.png`.

**Modified:** `pubspec.yaml` (asset registration), `lib/app/level_select_screen.dart`
(neutral background), `lib/games/runic_sudoku/runic_sudoku_screen.dart`
(chapter background).

## 3. Tests

`chapter_background_test.dart`: label→asset mapping for all four chapters,
neutral fallback for null/unknown, `forLevel` resolution via a `Progression`,
and `allAssets` count. Existing tests are unaffected (purely additive, visual
wrappers — no widget test renders the level select or puzzle screen).

## Implementation decisions I made

- **Used your provided art, not `ThemeRecord`.** `ThemeRecord`/`ThemeManager` is
  the *global* app theme (light/dark + symbol set); a per-chapter background keys
  off the chapter, which is orthogonal. Overloading `ThemeRecord` with a
  background would couple unrelated concerns and wouldn't vary per chapter, so I
  added a dedicated, centralized `ChapterBackgrounds` mapping instead (the
  smallest clean fit — `ThemeRecord` is untouched).
- **Keyed the mapping on the difficulty label** (`Quick`/`Normal`/`Tricky`/`Deep`),
  not the order-based `chapter_id`, so it stays correct if chapter ordering ever
  changes.
- **Matched the on-disk asset names.** The spec suggested `*_background`, but the
  files you placed are `*_bg.png` — I mapped to the actual files (read from disk).
- **Neutral default.** You provided 4 chapter backgrounds but no neutral; I
  generated a dark, low-weight `default_rune_bg.png` (~65 KB) for the campaign
  list and any unknown level.
- **Daily background.** The daily level is a pool level with a known chapter, so
  it shows that chapter's background. It remains purely visual and does not feed
  progression (consistent with the Phase 3.5 daily decoupling).
- **Readability overlay.** A solid black `ColoredBox` with adjustable opacity
  sits above the image and below the UI (0.5 in-puzzle, 0.6 on the list). The
  puzzle board itself stays opaque (`GridBoardStyle.background`), so the grid and
  rune input are fully legible; the art shows in the margins and behind panels. A
  missing-asset `errorBuilder` falls back to the theme surface color, so the
  screen can never break.
- **Performance.** Backgrounds are decoded once and held in Flutter's image
  cache; `BoxFit.cover` scales them. Your art is ~2 MB each (941×1672) which is
  fine to bundle; if low-end memory ever matters, add a `cacheWidth` to the
  `Image.asset` (noted below).

## Not implemented / deferred ideas

- **Per-section backgrounds inside the campaign list** — the list spans all
  chapters, so I used one neutral background rather than tinting each chapter
  section (cleaner, more readable). Could be added later.
- **Decode-size capping (`cacheWidth`)** — not added; trivial to add if profiling
  on low-end devices shows memory pressure from the ~2 MB art.
- **Animated / parallax backgrounds** — explicitly out of scope (no animations).
- **A `ThemeRecord.backgroundAsset` field** — not needed for this feature.

## Specification ambiguities

- **Asset names** — spec said `*_background`; the files present are `*_bg.png`. I
  used the actual files. **Review:** none needed unless you rename them.
- **"level select / chapter screen" background** — our level select is a single
  scrolling list of all chapters, so "the correct background" is ambiguous; I
  used the neutral background for it and the per-chapter art on the puzzle screen.
- **Leftover placeholder files** — I generated four placeholder `*_background.png`
  before noticing your `*_bg.png` art; the sandbox mount **blocked deleting**
  them, so they remain on disk but are **not bundled** (pubspec lists only the
  intended files) and **not referenced**. Safe to delete:
  `assets/backgrounds/{quick_runes,normal_seals,tricky_glyphs,deep_chambers}_background.png`.
