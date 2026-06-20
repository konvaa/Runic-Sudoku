# Runic Sudoku — Phase 1 implementation notes

Reusable app shell + grid core + the first Runic Sudoku vertical slice. No
universal engine, no plugin system, no ECS, no solver/generator. This document
follows the required output order: architecture plan, data models, code skeleton
(in `/lib`), tests (in `/test`), what is intentionally not implemented, the
implementation decisions made, deferred ideas, and specification ambiguities.

## 1. Architectural plan

Three layers, with strict dependency direction **App Core → game module → Grid
Core** (Grid Core depends on nothing app- or sudoku-specific):

- **Grid Core (`/lib/grid`)** — a sudoku-agnostic toolkit: coordinates,
  dimensions, box partition, a generic data layer, a presentation cell model, a
  tap→coordinate mapper, and a board widget that draws cells plus thick box
  boundaries. It knows geometry, not rules. It never imports the sudoku module.
- **App Core (`/lib/core` + `/lib/app`)** — the reusable shell: save service +
  local repository, analytics/ads/purchases service interfaces each with a valid
  no-op implementation, a theme manager with a symbol-set abstraction, and the
  menu / level-select / settings screens. App Core contains no game rules.
- **Runic Sudoku (`/lib/games/runic_sudoku`)** — the only place that knows
  row/column/box rules: pure rules, the snapshot type, mutable game state, a
  `ChangeNotifier` controller, the play screen, input/notes panels, and two
  hand-authored puzzles.

Services are plain objects passed by constructor through a small `AppServices`
locator (no DI framework). State management is `setState` for local UI and one
`ChangeNotifier` controller for game logic — nothing heavier.

## 2. Data models

- `GridCoordinate(row, col)`, `GridDimensions(rows, cols)`, `BoxShape(rows, cols)`
  — value types with JSON + token (`"6x6"`, `"2x3"`) helpers.
- `GridLayer<T>` — generic row-major data layer (`null` = empty).
- `GridCell` — presentation-only view model (primary glyph, note marks, given /
  selected / highlighted / error flags).
- `Snapshot` (abstract) → `RunicSudokuSnapshot` — the complete, serializable
  game state holding every Phase 0 field.
- `SaveTriggerType` — the ten trigger enum values with stable `wireName`s.
- `AdResult` / `AdStatus`, `PurchaseResult` / `PurchaseStatus`, `AnalyticsEvent`
  — stable Phase 1 result/payload contracts.
- `SymbolSet` / `VisualSymbol`, `ThemeRecord`, `ThemeManager` — theming + symbol
  abstraction (no fixed symbol count assumption).
- `ManualPuzzle` — a hand-authored fixture (solution, givens, difficulty, etc.).
- `RunicSudokuState` (mutable model) + `RunicSudokuController` (orchestration).

## 3 & 4. Code skeleton and tests

All source is under `/lib` following the requested file tree; tests are under
`/test`:

- `box_shape_test.dart` — every coordinate maps to the correct 2×3 box, all 36
  cells covered, 6 per box, exact box membership, edge detection, token round-trip.
- `runic_sudoku_rules_test.dart` — valid complete grid passes; isolated
  duplicate row / column / box each fail; placement helpers; win condition.
- `snapshot_serialization_test.dart` — serialize to JSON, restore from JSON, full
  round-trip equality (incl. a completed snapshot with `actual_solve_time`).

Run with `flutter test`. The project adds **no third-party runtime
dependencies** in Phase 1.

## 5. Intentionally NOT implemented (per the brief)

No puzzle **generator** and no **solver** (puzzles are hand-authored; rules only
validate). No **real ads**, **real purchases**, or **backend** (no-op services
with valid result types stand in). No **Shadow Maze** and no **general
plugin/engine** abstraction. The 4×4 tutorial is out of scope for this slice.
These are excluded to keep Phase 1 a minimal vertical slice; the contracts are
shaped so each can be added later behind the existing interfaces.

## Implementation decisions I made

These were not explicitly specified but had to be chosen. None add features.

- **`GridLayer<T>` type.** A generic, row-major `List<T?>` layer where `null`
  means empty, with `copy`, `fromRows`, `toRows`. It is Grid Core's reusable data
  primitive (a future game could use `GridLayer<String>`). The Runic Sudoku slice
  itself stores grids as `List<List<int>>` to mirror the Phase 0 snapshot schema
  1:1 and keep JSON trivial; `GridLayer.fromRows/toRows` bridges the two when a
  game wants the typed layer. Flagging this because `GridLayer` is therefore part
  of the Grid Core API but not consumed by the Phase 1 game.
- **Box-boundary highlighting in `GridBoardWidget`.** The widget receives the
  `BoxShape` as data and a `GridBoardStyle` (colors/line widths) from the host. A
  single `CustomPainter` draws thin cell lines, then thick lines at every multiple
  of `boxShape.rows`/`boxShape.cols`, then a thick outer frame. The host passes
  theme colors in; Grid Core never reads the app theme.
- **Tap input.** The board uses one `GestureDetector` + `GridInputMapper`
  (pixel→coordinate) rather than per-cell widgets, so the mapper is genuinely
  exercised and reusable for future input sources.
- **`AdResult` shape.** `class AdResult { AdStatus status; bool rewardGranted;
  String? placement; String? message; }` with named constructors
  (`.completed/.shown/.skipped/.failed/.notAvailable`) and
  `enum AdStatus { completed, shown, skipped, failed, notAvailable }`. It is a
  **Phase 1 internal contract**, intended to survive real SDK integration
  unchanged via an adapter that maps AdMob/Unity callbacks into it — it is **not**
  assumed to map 1:1 to any SDK, and is deliberately not over-engineered.
- **`PurchaseResult` shape.** `class PurchaseResult { PurchaseStatus status;
  String productId; String? message; bool get isEntitled; }` with
  `enum PurchaseStatus { success, alreadyOwned, cancelled, pending, failed,
  notAvailable }` and a `ProductIds.removeAds` constant. Same intent as
  `AdResult`: stable internal contract, real Play Billing/StoreKit integration
  arrives behind a mapping layer; sufficient for Phase 1 and expected to survive
  real integration unchanged.
- **`AnalyticsEvent` payload.** `{ String name; Map<String,Object?> params;
  DateTime timestamp; }` with primitive-only params so any backend adapter can
  consume it.
- **`VisualSymbol` structure.** `{ String id; String glyph; String? assetPath;
  Color? color; String displayName; String accessibilityLabel; }`. Rendering
  precedence: draw `assetPath` if present, else draw `glyph` as text (so `glyph`
  doubles as the asset fallback). Chosen explicitly instead of Flutter
  `IconData`, a bare string, or a bare asset path, so a symbol set can carry
  custom artwork **and** a text fallback **and** accessibility metadata together.
- **`SymbolSet` structure.** `{ String id; List<VisualSymbol> symbols; }`. I
  **consolidated** the prompt's parallel `displayNames` / `accessibilityLabels`
  lists into fields on `VisualSymbol` (see "Specification ambiguities"). The
  sudoku-specific "needs exactly 6 symbols" check lives in
  `RunicSudokuRules.requireSymbolCount`, **not** in App Core / Theme Manager.
- **Controller ↔ save service.** `controller.save(trigger)` folds elapsed time
  into state, builds a `RunicSudokuSnapshot` via `state.toSnapshot()`, and calls
  `saveService.save(snapshot, trigger)`. Loading uses
  `RunicSudokuController.loadOrCreate`, which calls `saveService.load(saveKey)`
  and rebuilds via `RunicSudokuSnapshot.fromJson`. App Core's `SaveService.load`
  returns raw JSON (it cannot know game types); the game module deserializes.
- **`elapsed_time` measurement.** A `Stopwatch` in the controller; `elapsed =
  persisted base (state.elapsedTime) + stopwatch.elapsed`. It is folded into
  state on every save, on pause, and on win. A 1-second `Timer` calls
  `notifyListeners` so the on-screen clock ticks. `actual_solve_time` is set to
  the folded elapsed time at the moment of completion.
- **Save backend.** `LocalSaveRepository` persists JSON via an injectable
  `SaveStore`; Phase 1 ships only `InMemorySaveStore` (zero dependencies, fully
  testable). Persistent storage (e.g. `shared_preferences` or a JSON file) is a
  Phase 2 swap behind the same interface.
- **`mistakes_count` semantics.** Incremented when a placed value disagrees with
  the solution at entry time; the "Check" action only *highlights* current
  discrepancies and does not change the count (avoids double-counting).
- **Puzzle `seed`.** Fixed constants (1001 / 1002) for the hand-authored
  puzzles, since there is no generator; the field is retained for schema and
  future generator compatibility.

## Not implemented / deferred ideas

Things I considered but deliberately kept out of Phase 1 code.

- **Undo/redo stack.** *Useful:* forgiving input, standard in sudoku apps. *Not
  now:* adds a command/history model beyond a minimal slice. *Later:* Phase 2,
  inside the controller.
- **Multiple save slots / autosave history.** *Useful:* recover from mistakes,
  multiple in-progress puzzles. *Not now:* one slot per (game, level) is enough
  to prove save/load. *Later:* Phase 2, via the existing `SaveStore` key scheme.
- **Persistent storage backend.** *Useful:* survives app restart. *Not now:*
  would add a dependency + platform config the brief asks me to justify. *Later:*
  Phase 2 `SharedPreferencesSaveStore`/file store behind `SaveStore`.
- **4×4 tutorial mode.** *Useful:* onboarding. *Not now:* explicitly later per
  Phase 0. *Later:* reuses Grid Core + a `numericSet`; only a 4-symbol validation
  differs.
- **Auto-pencil / candidate computation.** *Useful:* quality-of-life. *Not now:*
  it is solver-adjacent and could creep toward an engine. *Later:* Phase 2, as a
  pure helper in the rules module.
- **Localization (cs/en).** *Useful:* the user is Czech-speaking. *Not now:* UI
  strings are minimal in a skeleton. *Later:* Phase 2 via `flutter_localizations`.

## Specification ambiguities

Conflicts between this prompt and the Phase 0 schema, and how I resolved them.

- **`box_shape` as `"2x3"` string vs structured.** Phase 0 stores a string. I use
  a structured `BoxShape(rows, cols)` internally and serialize to/from the
  `"2x3"` token. **Review before Phase 2?** No — it is backward compatible.
- **`grid_size` as `"6x6"` string vs structured.** Same resolution as
  `box_shape`: structured `GridDimensions`, serialized as `"6x6"`. No review
  needed.
- **`given_cells` representation.** The schema lists `given_cells` but not its
  shape. I model it as a `List<List<int>>` clue grid (0 = not given), which
  doubles as the "is given" mask and the initial `current_grid`. **Review before
  Phase 2?** Light — confirm the desired wire shape if Phase 0 expected a list of
  coordinates instead.
- **`SymbolSet` parallel lists vs consolidated.** The prompt's example shows
  parallel `symbols` / `displayNames` / `accessibilityLabels` lists. I instead put
  `displayName` and `accessibilityLabel` on each `VisualSymbol` to make desync
  impossible. **Review before Phase 2?** Worth a glance, since it diverges from the
  example, but it is strictly safer and the `SymbolSet` id/length contract is
  unchanged.
- **`notes_grid` shape.** Stored as a per-cell sorted `List<int>` of candidate
  values (row-major), held in memory as `Set<int>`. No review needed.
- **`seed` with no generator.** Ambiguous purpose in a hand-authored Phase 1. Kept
  as a stable per-puzzle constant for schema/forward compatibility. Revisit when
  the generator lands.

None of these ambiguities were used to expand scope.
