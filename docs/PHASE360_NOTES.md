# Phase 3.60 — UI visual polish

Purely visual. No gameplay, progression, solver, generator, save, hint, or
monetization changes. The white sudoku grid is intentionally kept (good contrast).

## What changed

1. **Dark AppBar + system bars** — `AppTheme.fromRecord` now sets a global dark
   `AppBarTheme` (`#0D0D0D` background, `#F2EAD8` title/back, light status icons),
   so the puzzle, level-select and settings AppBars match in one place. `main()`
   sets `SystemChrome` overlay (light status/nav-bar icons). The main menu has no
   AppBar and is untouched.
2. **Contrastive HUD panel** — the unreadable text row is replaced by `_PuzzleHud`:
   a dark semi-opaque panel (`Colors.black` @ 0.8 + subtle gold border) with three
   blocks `⏱ time · ✕ mistakes · 💡 hints` in light text.
3. **Rune input panel** — dark "rune coins" (`#1A1208` fill, gold `#E0A94A`
   glyph, circular); erase button is a gold-outlined circle. Grid kept white.
4. **Rename** — the user-facing "Campaign" → **"Rune Trials"** (main-menu button +
   level-select title). Internal names (`campaignProgress`, chapter ids, …)
   unchanged.

## Files changed

`lib/core/theme/app_theme.dart` (dark AppBarTheme), `lib/main.dart` (SystemChrome
overlay), `lib/games/runic_sudoku/runic_sudoku_screen.dart` (`_PuzzleHud` replaces
`_StatusBar`), `lib/games/runic_sudoku/rune_input_panel.dart` (dark/gold styling),
`lib/app/main_menu_screen.dart` + `lib/app/level_select_screen.dart` (rename),
`test/widget_test.dart` (label updated to "Rune Trials").

## Implementation decisions I made

- **HUD = dedicated widget** (`_PuzzleHud`), not inline — it owns its panel and
  keeps `_buildBody` readable. It also still hosts the `format` helper used by the
  win dialog.
- **HUD background = `Colors.black` @ 0.8 opacity + a faint gold border, light
  text.** Contrast is guaranteed by the dark *fill*, not the text color, so it
  stays legible on all four chapter backgrounds (brown / brown / blue / purple)
  regardless of their hue. 0.8 (not fully opaque) keeps a hint of the art while
  staying clearly readable; the gold hairline ties it to the rune palette.
- **Dark AppBar = global** via `AppBarTheme` (one change, consistent across every
  AppBar screen) rather than per-screen overrides. `SystemChrome` is set once in
  `main`.
- **Rune input = direct colors via `styleFrom`** (dark fill + gold glyph, circular
  coins; gold-outline erase). Direct colors (not a derived theme) keep them
  predictable regardless of the global light/dark theme.

## Specification ambiguities

- **Global ThemeData is light by default** (`ThemeManager` starts on
  `AppThemes.runesLight`). That is why the AppBar/buttons were light. I made the
  **AppBar** dark globally but did NOT flip the whole app to the dark theme
  (out of scope). Consequence: the **settings body** stays light Material under
  its now-dark AppBar (only the AppBar was in scope for settings). If you want the
  entire app dark by default, switch `ThemeManager`'s initial theme to
  `AppThemes.runesDark` — a broader, separate decision.

## Verification

Sandbox has no Dart SDK, so `flutter test` / `flutter analyze` were not run here.
Changes are visual; logic is untouched. The widget smoke test was updated for the
"Rune Trials" label and still asserts the three menu entries. Please run
`flutter test` and `flutter analyze`.
