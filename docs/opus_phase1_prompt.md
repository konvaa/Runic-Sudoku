Vytvoř implementační návrh a kódovou kostru pro Flutter projekt, který bude sloužit jako reusable base pro několik jednoduchých grid-based mobilních her.

Důležité omezení:
Nedělej univerzální herní engine. Nedělej plugin systém. Nedělej ECS. Nedělej solver/generator. Cílem je minimální reusable app shell + grid core + první vertical slice pro Runic Sudoku.

Vstupní kontext:
Projekt vychází z Phase 0 specifikace pro Runic Sudoku / Rune Grid:

- první hra je 6×6 runové sudoku s 2×3 boxy,
- 4×4 je jen tutorial později,
- MVP fáze 1 má používat ručně zadané puzzle,
- generátor a solver nejsou součást tohoto tasku,
- společné části mají být App Core a Grid Core,
- sudoku pravidla musí zůstat v Runic Sudoku modulu,
- save systém používá complete snapshot saves přes save(snapshot, trigger_type).

Cíl tasku:
Navrhni a vytvoř základ projektu pro Fázi 1:

- App Core
- Grid Core
- Runic Sudoku vertical slice
- základní UI kostru
- testy pro nejdůležitější modely

Požadovaná architektura:

```
/lib
  /app
    app.dart
    routes.dart
    main_menu_screen.dart
    settings_screen.dart
    level_select_screen.dart

  /core
    /save
      save_service.dart
      save_trigger_type.dart
      snapshot.dart
      local_save_repository.dart

    /analytics
      analytics_service.dart
      noop_analytics_service.dart

    /ads
      ads_service.dart
      noop_ads_service.dart

    /purchases
      purchase_service.dart
      noop_purchase_service.dart

    /theme
      app_theme.dart
      theme_record.dart
      rune_set.dart
      theme_manager.dart

  /grid
    grid_coordinate.dart
    grid_dimensions.dart
    box_shape.dart
    grid_layer.dart
    grid_cell.dart
    grid_input_mapper.dart
    grid_board_widget.dart

  /games
    /runic_sudoku
      runic_sudoku_screen.dart
      runic_sudoku_state.dart
      runic_sudoku_snapshot.dart
      runic_sudoku_rules.dart
      runic_sudoku_controller.dart
      rune_input_panel.dart
      notes_panel.dart
      manual_puzzle.dart

/test
  box_shape_test.dart
  runic_sudoku_rules_test.dart
  snapshot_serialization_test.dart
```

Požadavky na App Core:

- jednoduché hlavní menu
- level select shell
- settings screen
- theme manager
- save service interface
- local save repository
- analytics service interface s no-op implementací
- ads service interface s no-op implementací
- purchase service interface s no-op implementací

Požadavky na Grid Core:

- musí být agnostický vůči sudoku
- nesmí znát pravidla row/column/box
- musí umět reprezentovat grid_size a box_shape jako data
- musí podporovat vykreslení gridu a zvýraznění silnějších hranic boxů
- musí podporovat input mapping z tapnutí na grid coordinate
- musí být použitelný později i pro jiné grid hry

Požadavky na Runic Sudoku modul:

- ručně zadané 6×6 puzzle:
  - solution_grid
  - given_cells
  - current_grid
  - box shape 2×3
- výběr buňky
- vložení hodnoty 1–6
- poznámky/candidates mode
- validace podle solution_grid nebo live constraints
- win condition current_grid == solution_grid
- snapshot save/load
- app_pause trigger uloží snapshot

Snapshot schema:
RunicSudokuSnapshot musí obsahovat:

- game_id
- level_id
- seed
- grid_size
- box_shape
- solution_grid
- given_cells
- current_grid
- notes_grid
- mistakes_count
- hints_used
- started_at
- elapsed_time
- last_saved_at
- completed
- difficulty_label
- estimated_solve_time
- actual_solve_time

Trigger typy:

- level_start
- placement_complete
- notes_changed
- hint_used
- mistake_checked
- level_complete
- app_pause
- rewarded_ad_completed
- interstitial_shown
- purchase_completed

Testy:
Vytvoř unit testy pro:

- 6×6 2×3 box mapping:
  - každá souřadnice se mapuje do správného boxu
  - všech 36 buněk je pokryto
- validace řádku/sloupce/boxu:
  - validní complete grid projde
  - duplicate row selže
  - duplicate column selže
  - duplicate box selže
- snapshot serialization:
  - snapshot lze serializovat do JSON
  - snapshot lze obnovit z JSON
  - obnovený snapshot odpovídá původnímu

Výstup:

1. Nejprve napiš stručný architektonický plán.
2. Potom navrhni datové modely.
3. Potom napiš kódovou kostru.
4. Potom napiš testy.
5. Na konci napiš, co záměrně není implementováno a proč.

Důležité:

- Nepřidávej generator.
- Nepřidávej solver.
- Nepřidávej reálné reklamy.
- Nepřidávej reálné nákupy.
- Nepřidávej backend.
- Nepřidávej Shadow Maze.
- Nepřidávej žádný obecný plugin engine.
- Drž scope na Fázi 1.

Pokud budeš mít chuť přidat něco chytrého navíc, nejdřív vysvětli riziko a nezařazuj to do kódu.

---

Doplňující technická omezení pro implementaci:

**No-op služby**

No-op implementace nesmí vracet null, throw, prázdné placeholdery nebo nevalidní výsledky.

Musí vracet realistické validní výsledky, aby volající kód šel později napojit na reálné reklamy, analytiku a nákupy beze změny API.

Příklad:

- NoopAdsService.showRewardedAd() vrací Future<AdResult.completed>
- NoopAdsService.showInterstitial() vrací validní výsledek typu AdResult.shown nebo AdResult.skipped, podle navrženého enumu
- NoopAnalyticsService.logEvent(...) bezpečně dokončí bez chyby
- NoopPurchaseService.purchaseRemoveAds() vrací validní PurchaseResult.success nebo jasně definovaný mock výsledek

Definuj enumy/datové typy pro:

- AdResult
- PurchaseResult
- analytics event payload

Tyto typy musí být stabilní API contract, ne dočasný placeholder.

**Theme / SymbolSet / RuneSet boundary**

App Core nesmí předpokládat, že každý symbol set má přesně 6 symbolů.

V /core/theme/ definuj obecnější datovou strukturu, například:

```
SymbolSet
  id
  symbols: List<VisualSymbol>
  displayNames: List<String>
  accessibilityLabels: List<String>
```

Runic Sudoku modul si z ní vezme a validuje právě 6 symbolů pro 6×6 režim.

Sudoku-specific validace typu „potřebuji přesně 6 symbolů" patří do Runic Sudoku modulu, ne do App Core / Theme Manageru.

Theme může odkazovat na symbol_set_id, ale Theme Manager nesmí obsahovat sudoku pravidla.

**Manual puzzle fixtures**

manual_puzzle.dart musí obsahovat minimálně dvě ručně zadaná 6×6 puzzle:

A) quick_test_puzzle
- téměř hotové puzzle
- má jen několik prázdných buněk
- slouží k rychlému testování win condition, save/load a dokončení levelu

B) notes_test_puzzle
- má více prázdných buněk
- slouží k testování notes/candidates režimu, validace a běžného hraní

Obě puzzle musí obsahovat:

- solution_grid
- given_cells
- difficulty_label
- estimated_solve_time
- level_id

**State management**

Použij nejjednodušší vhodný state management.

Preferuj:

- StatefulWidget / setState pro lokální UI stav
- jednoduchý controller typu ChangeNotifier, pokud je potřeba oddělit logiku od widgetu

Nepoužívej těžké frameworky jako BLoC, Redux nebo komplexní dependency injection. Cílem je čitelnost, jednoduchost a snadná migrace, ne architektonická dokonalost.

Pokud navrhneš externí dependency, musíš vysvětlit:

- proč je nutná,
- co by bylo složitější bez ní,
- proč není overkill pro Phase 1.

**Implementation decisions log**

Na konci výstupu uveď samostatnou sekci:

"Implementation decisions I made"

V ní vypiš všechna rozhodnutí, která nebyla explicitně zadána v promptu, ale musel jsi je během návrhu/kódu udělat.

Například:

- jaký konkrétní typ má GridLayer
- jak GridBoardWidget přijímá zvýraznění box boundaries
- jaký tvar má AdResult
- jak je strukturován SymbolSet
- jak controller komunikuje se save service
- jak se měří elapsed_time v prototypu

Nepřidávej nové funkce. Jen transparentně označ nutná implementační rozhodnutí, aby je bylo možné zkontrolovat.

**Anti-drift pravidlo**

Pokud tě napadne přidat něco nad rámec promptu, nezařazuj to do kódu.

Místo toho to napiš do samostatné sekce:

"Not implemented / deferred ideas"

U každé položky napiš:

- proč by to mohlo být užitečné,
- proč to není součást Phase 1,
- v jaké pozdější fázi by to případně dávalo smysl.

Znovu: cílem není perfektní univerzální engine. Cílem je minimální reusable app shell + grid core + Runic Sudoku Phase 1 vertical slice.

---

Final clarification before implementation:

**1. AdResult / PurchaseResult are Phase 1 internal contracts**

Define `AdResult` and `PurchaseResult` as stable Phase 1 interfaces for the app shell, but do not assume they map 1:1 to any future real ads/IAP SDK.

When real AdMob / Unity Ads / Play Billing integration is added later, it must use a mapping layer from SDK callbacks/events into these internal result types.

At the end, include in "Implementation decisions I made":

- the exact shape of `AdResult`
- the exact shape of `PurchaseResult`
- whether the result model is sufficient for Phase 1 only or intended to survive real SDK integration unchanged

Do not over-engineer these result types for SDKs that are not being integrated in Phase 1.

**2. VisualSymbol must be explicit**

If you introduce a `VisualSymbol` type inside `SymbolSet`, define its structure clearly.

Example acceptable structures:

- asset path / asset reference
- fallback text glyph
- optional color/style metadata
- accessibility label reference

If you choose a different representation, list it in "Implementation decisions I made" and explain why.

Do not silently use Flutter `IconData`, raw strings, or asset paths without documenting the choice.

**3. Specification ambiguities**

If you find a conflict or mismatch between this prompt and the Phase 0 specification, do not silently choose one interpretation without warning.

Create a final section:

"Specification ambiguities"

For each ambiguity, write:

- what the conflict is
- which interpretation you used for the code
- why
- whether the decision should be reviewed before continuing to Phase 2

Example:

- Phase 0 stores `box_shape` as `"2x3"` string, but the code may naturally prefer `BoxShape(rows: 2, cols: 3)`.
- In that case, use the structured model internally, serialize to/from `"2x3"` if needed, and document the decision.

Do not use ambiguities as an excuse to expand scope.
