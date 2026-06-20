Vytvoř implementační návrh a kód pro generátor a dva solvery pro Runic Sudoku, podle Phase 0 specifikace (sekce 3, 4, 5) a na základě existující Phase 1 kostry (`/lib/games/runic_sudoku`, `/lib/grid`).

Důležité omezení:
Nedělej univerzální constraint-solver engine. Nedělej obecný "sudoku variant" systém (žádný Killer Sudoku, Jigsaw, diagonály). Nedělej UI integraci hint systému (to je Phase 3). Cílem je: dva solvery + generátor + jejich testy, napojené na existující datové modely, ale bez zásahu do App Core nebo UI vrstev.

Vstupní kontext:
Phase 1 už existuje a obsahuje:

- `GridCoordinate`, `GridDimensions`, `BoxShape` — value types s JSON/token helpery
- `RunicSudokuRules` — validace row/column/box, win condition
- `RunicSudokuSnapshot` — kompletní schema (viz Phase 0 sekce 6.3)
- `ManualPuzzle` — fixtures (`quick_test_puzzle`, `notes_test_puzzle`)

Generátor a solvery musí tyto existující typy znovu použít, ne duplikovat. Pokud narazíš na to, že existující typ (např. `BoxShape`, `GridCoordinate`) nesedí na potřeby solveru, neopravuj ho tiše — zapiš to do "Specification ambiguities" (viz níže) a navrhni minimální, neinvazivní úpravu.

**Důležitá pojistka**: piš solver i generátor parametricky vůči `grid_size` a `box_shape`, ne hardcoded na hodnotu 6 nebo `2x3`. I když MVP používá jen 6×6, kód nesmí mít natvrdo zapsané rozměry — to je požadavek na čistotu architektury, ne na přidání 9×9 podpory teď. Nepřidávej žádnou logiku specifickou pro jiné velikosti gridu; jen nepiš kód, který by jinou velikost vyloučil.

---

Cíl tasku:

1. **Fast Uniqueness Solver** (Phase 0, sekce 4.1)
   - Účel: ověření unikátnosti řešení při generování, voláno potenciálně tisíckrát na jeden puzzle.
   - Metoda: constraint propagation + backtracking.
   - Parametr `max_solutions = 2`, hledání se zastaví okamžitě po nalezení druhého řešení.
   - Výstup: `0`, `1`, nebo `2` (2 = "2 nebo víc").
   - Nesmí logovat techniky, nesmí počítat obtížnost. Optimalizovat čistě na rychlost.

2. **Human-Like Difficulty Solver** (Phase 0, sekce 4.2)
   - Účel: hodnocení obtížnosti po vygenerování, voláno jednou na puzzle.
   - Metoda: candidate generation (eliminace kandidátů podle row/column/box) jako kontinuální krok, NE jako "solving technique". Po něm aplikace MVP technik v pořadí:
     1. Naked single
     2. Hidden single
   - Žádné jiné techniky v MVP (pointing pairs, box/line reduction jsou Future — nepiš je, ale neuzavírej strukturu tak, aby šly přidat později).
   - Výstup musí obsahovat přesně:
     - `difficulty_score`
     - `decision_points_count`
     - `forced_moves_count`
     - `candidate_complexity`
     - `estimated_solve_time`
     - `unsupported_technique` (bool)
     - `solver_steps_log` (ordered list `{cell, technique, value}`)
   - Implementuj formální definice z Phase 0 sekce 3.1 přesně:
     - `forced_moves_count` = počet buněk vyřešených naked/hidden single
     - `decision_points_count` = kroky, kde naked/hidden single nestačí, ale human-like solver (jen s MVP technikami) může pokračovat — buď přes podporovanou techniku nad naked/hidden single, nebo stav s více než N buňkami (N=3, tunable konstanta) se ≥2 kandidáty, kde se naked/hidden single zpřístupní až po dalším umístění
     - `candidate_complexity` = normalizovaný (0.0–1.0) průměr velikosti kandidátních množin, váženo směrem k buňkám se 3+ kandidáty, podle vzorce: `(sum over empty cells of max(0, candidates(cell) - 2)) / (empty_cell_count * (grid_size - 2))`
     - `estimated_solve_time` = `(forced_moves_count * T_forced) + (decision_points_count * T_decision) + (candidate_complexity * T_complexity_modifier)`, s MVP konstantami `T_forced = 3`, `T_decision = 12`, `T_complexity_modifier = 30` (sekundy). Tyto konstanty musí být v kódu jasně oznčené jako placeholder/heuristika, ne odvozená z dat, a snadno upravitelné na jednom místě.
   - **Klíčové pravidlo**: pokud solver nedokáže puzzle plně vyřešit pomocí MVP technik, nesmí to být tiše interpretováno jako "vyšší obtížnost". Musí nastavit `unsupported_technique = true` a `difficulty_label` se v takovém případě NEPŘIŘAZUJE.
   - Nesmí potřebovat rychlost — běží jednou na puzzle.

3. **Generator** (Phase 0, sekce 5)
   - Pipeline: (a) vygeneruj kompletní validní mřížku randomizovaným backtrackingem, (b) odebírej buňky v náhodném pořadí, po každém odebrání ověř unikátnost Fast Uniqueness Solverem — pokud `== 1`, pokračuj, pokud `>= 2`, vrať hodnotu zpět, (c) zastav se, když už nelze nic odebrat bez ztráty unikátnosti nebo je dosažen cílový počet prázdných buněk pro danou obtížnost, (d) ohodnoť výsledné puzzle Human-Like Solverem, (e) aplikuj rejection rules (viz níže), při zamítnutí buď restartuj od (a) s novým seedem, nebo zkus jiné pořadí odebírání ze stejné plné mřížky, (f) ulož `given_cells` + `solution_grid` jako kanonická data, seed jen jako debug/doplňkové info (NE jako jediný zdroj pravdy pro reprodukci — to je už rozhodnuté z Phase 0/Phase 1).
   - Rejection rules (puzzle se zamítne, pokud platí kterákoliv z těchto podmínek):
     - `unsupported_technique == true`
     - `decision_points_count == 0` pro jakýkoliv difficulty label jiný než `Quick`
     - `estimated_solve_time` je o víc než 20 % pod minimální hranicí cílového labelu
     - puzzle je řešitelné čistě forced moves od počátečního stavu (a label není `Quick`)
   - Label mapping (Phase 0 sekce 3.2):
     - Quick: 30–120s, typicky 0 decision points
     - Normal: 60–180s, typicky 1–2
     - Tricky: 180–360s, typicky 2–4
     - Deep: 300–600s, typicky 4+
   - Generátor musí umět: vygenerovat puzzle pro konkrétní cílový difficulty label (vstupní parametr), export/import levelu jako JSON (`{grid_size, box_shape, solution_grid, given_cells, difficulty_label}`), reprodukovatelnost ze stored dat (ne ze seedu).
   - Explicitně NEPŘIDÁVEJ: elementární constraints, multi-region puzzles, nepravidelné box shapes, 9×9 podporu (i když kód musí být parametrický, jak je uvedeno výše).

---

Architektura a umístění souborů:

Navrhuji (uprav, pokud existující struktura velí jinak, ale zdůvodni v "Implementation decisions"):

```
/lib/games/runic_sudoku
  /solver
    fast_uniqueness_solver.dart
    human_like_solver.dart
    solver_step.dart          (typ pro {cell, technique, value})
    solving_technique.dart    (enum: nakedSingle, hiddenSingle, ...)
  /generator
    puzzle_generator.dart
    full_grid_generator.dart
    cell_removal.dart
    difficulty_scorer.dart    (pokud chceš oddělit scoring od solveru samotného)
    level_data.dart           (export/import JSON schema)

/test
  fast_uniqueness_solver_test.dart
  human_like_solver_test.dart
  puzzle_generator_test.dart
```

---

Testy musí pokrývat minimálně:

**Fast Uniqueness Solver**:
- puzzle se známým unikátním řešením vrací `1`
- puzzle s víc řešeními vrací `2`
- nevalidní/nesplnitelné puzzle vrací `0`
- zastaví se okamžitě po nalezení druhého řešení (lze ověřit přes výkon/krok počítadlo, ne jen výsledek)

**Human-Like Solver**:
- triviální puzzle (jen naked/hidden singles) vrací `forced_moves_count > 0`, `decision_points_count == 0`, `unsupported_technique == false`
- puzzle navržené tak, aby vyžadovalo "decision point" podle definice (více než N buněk se ≥2 kandidáty) vrací `decision_points_count > 0`
- puzzle, které MVP solver nedokáže vyřešit, vrací `unsupported_technique == true` a nemá přiřazený `difficulty_label`
- `solver_steps_log` odpovídá pořadí a obsahu skutečně provedených kroků

**Generator**:
- vygenerovaná plná mřížka splňuje všechny row/column/box constraints
- po cell removal má výsledný puzzle přesně jedno řešení (ověřeno Fast Uniqueness Solverem)
- generátor pro cílový label `Quick` vrací puzzle s `decision_points_count == 0`
- generátor pro cílový label jiný než `Quick` nikdy nevrátí puzzle s `decision_points_count == 0`
- level lze exportovat do JSON a znovu importovat se shodným `solution_grid` + `given_cells`
- generátor odmítne/zahodí puzzle, které selže na rejection rules (lze testovat vložením uměle vytvořeného "trivial" kandidáta a ověřením, že se nedostane do finálního výstupu)

---

Výstup (stejný formát jako Phase 1):

1. Stručný architektonický plán.
2. Datové modely.
3. Kódová kostra.
4. Testy.
5. Co záměrně není implementováno a proč.

---

Doplňující technická omezení (platí stejně jako v Phase 1):

**Implementation decisions log**

Na konci uveď sekci "Implementation decisions I made" se všemi rozhodnutími, která nebyla explicitně zadána. Konkrétně očekávám vysvětlení k:
- jak přesně je definovaný a implementovaný "decision point" check (N=3 threshold) v kódu
- jak je strukturovaný `SolverStep`/`solver_steps_log`
- jak generátor rozhoduje o "cílovém počtu prázdných buněk" per difficulty label (jaký je vztah mezi tímto číslem a label mapping tabulkou)
- potvrzení, že solver a generátor jsou skutečně parametrické vůči `grid_size`/`box_shape`, ne hardcoded na 6×6 — pokud někde zůstal hardcoded předpoklad, explicitně to uveď

**Anti-drift pravidlo**

Pokud tě napadne přidat něco navíc (např. další solving technika, optimalizace, cache mechanismus), nezařazuj to do kódu. Zapiš to do "Not implemented / deferred ideas" se zdůvodněním proč ne teď a kdy by to dávalo smysl.

**Specification ambiguities**

Pokud najdeš konflikt mezi touto specifikací, Phase 0 dokumentem, nebo existující Phase 1 kostrou, nerozhoduj tiše. Zapiš to do "Specification ambiguities" se stejnou strukturou jako v Phase 1 (co je konflikt, jakou interpretaci jsi zvolil, proč, jestli je třeba review před další fází).

**Performance pojistka**

Generátor bude volat Fast Uniqueness Solver opakovaně (desítky až stovky volání na jeden puzzle). Pokud zvolíš implementaci, která by toto dělala neefektivně (např. zbytečné re-alokace celé mřížky při každém volání), zdůvodni svou volbu v "Implementation decisions" — neoptimalizuj předčasně, ale ukaž, že jsi o tom přemýšlel.

Důležité: nepřidávej žádné externí dependencies. Solver a generátor jsou čistá Dart logika bez Flutter/UI závislostí (musí být testovatelné bez Flutter test frameworku, pokud to architektura Phase 1 dovoluje — pokud ne, vysvětli proč).
