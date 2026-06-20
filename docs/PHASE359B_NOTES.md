# Main menu visual fix — dark fantasy styling

Purely visual: the main menu now matches the game's dark stone + gold-rune look
(it was rendering on the default light Material theme). No gameplay, progression,
monetization, or navigation changes.

## What changed

- `lib/app/main_menu_screen.dart` only. The body is wrapped in the existing
  `ChapterBackground` (stone image + dark overlay), and the title/logo/buttons
  use light/gold colors. Every `onPressed` target is identical to before.

## Implementation decisions I made

- **Background asset.** Used `assets/backgrounds/default_rune_bg.png` via the
  shared `ChapterBackground` widget (overlay opacity 0.55) — the same neutral
  background the campaign list uses, so the menu reads as the same app and the
  "entry hall" stays chapter-agnostic. It exists, so the `quick_runes_bg.png`
  fallback wasn't needed. Reusing `ChapterBackground` keeps the dark-overlay
  pattern consistent across screens.
- **Button / text colors via `styleFrom`, not a custom `ThemeData`.** I applied
  explicit colors per widget (gold fill + dark text for the Daily/Campaign
  primaries, a light outline for Settings, gold/light title and streak text)
  rather than wrapping the screen in a dark `Theme`. Reason: a local `styleFrom`
  is predictable and self-contained, whereas swapping the screen's `ThemeData`
  would cascade into any pushed dialogs/screens and is easy to get subtly wrong.
  Colors: gold `#E0A94A`, on-gold `#120E08`, light `#F2EAD8`.

## Specification ambiguities

- **Global theme is light by default.** The menu looked beige because
  `ThemeManager` starts on `AppThemes.runesLight` (first in the list), so the
  default `ThemeData` is light. I did **not** change that global default (out of
  scope, and it would affect every screen); I styled the menu locally instead. If
  you'd prefer the whole app to default to the dark theme, set `ThemeManager`'s
  initial theme to `AppThemes.runesDark` — a broader, separate change to decide
  deliberately.

## Verification

Sandbox has no Dart SDK, so `flutter test` / `flutter analyze` were not run here.
The change is visual only; the widget smoke test still finds the `Daily Puzzle`,
`Campaign`, and `Settings` labels (still `Text` inside the buttons), and
`ChapterBackground`'s `errorBuilder` falls back to a solid color if the asset
isn't loaded in the test bundle, so the smoke test stays green. Please run
`flutter test` to confirm.
