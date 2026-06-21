Phase 3.65 — Generator Audit / Diagnostic.

Čistě diagnostický task — žádné změny produkčního kódu, žádné nové features, žádné UI změny.

Než cokoliv napíšeš, přečti si z disku:
- `lib/games/runic_sudoku/generator/puzzle_generator.dart`
- `lib/games/runic_sudoku/generator/difficulty_scorer.dart`
- `lib/games/runic_sudoku/generator/level_data.dart`
- `lib/games/runic_sudoku/solver/human_like_solver.dart`
- `lib/games/runic_sudoku/solver/difficulty_constants.dart`
- `tool/generate_level_pool.dart` (jako referenci jak se generátor volá)

---

Cíl: ověřit, že generátor produkuje dostatečně kvalitní a dostatečně rychlé puzzle ve velkém měřítku, aby byl použitelný pro on-demand generování v Free Play režimu (kde hráč čeká na výsledek v reálném čase).

---

Vytvoř diagnostický skript `tool/generator_audit.dart` který:

**1. Objem a rychlost**
Pro každý difficulty label (Quick, Normal, Tricky, Deep):
- Pokus se vygenerovat 200 puzzle (ne 1000 — to by trvalo příliš dlouho na Deep)
- Měř čas každého generování (wall-clock time per puzzle)
- Zaznamenej počet odmítnutých kandidátů (rejection rate) per puzzle
- Vypiš: průměrný čas, P50, P95, P99, max čas generování
- Vypiš: průměrný počet odmítnutých kandidátů, P95

**2. Kvalita puzzle**
Pro každý vygenerovaný puzzle zaznamenej:
- `estimated_solve_time`
- `candidate_complexity`
- `decision_points_count`
- `forced_moves_count`
- `unsupported_technique` (pokud true, to je chyba — nemělo by se stát)
Vypiš distribuci těchto hodnot (min, avg, P50, P95, max) per label.

**3. Duplicity**
Ověř, že mezi 200 vygenerovanými puzzle pro každý label nejsou duplicity (stejný `given_cells` pattern). Vypiš počet duplicit pokud existují. Na 6×6 by duplicity být neměly, ale stojí za ověření.

**4. Export vzorků pro ruční kontrolu**
Z každého labelu exportuj 5 náhodně vybraných puzzle do souboru `tool/audit_samples.json` ve formátu:
```json
{
  "Quick": [ { puzzle1 }, { puzzle2 }, ... ],
  "Normal": [ ... ],
  "Tricky": [ ... ],
  "Deep": [ ... ]
}
```
Každý vzorek musí obsahovat `solution_grid`, `given_cells`, `difficulty_label`, `estimated_solve_time`, `candidate_complexity`, `decision_points_count`.

**5. Free Play viability assessment**
Na základě naměřených dat odpověz na tyto otázky v textovém výstupu skriptu:
- Je P95 čas generování pro Quick/Normal pod 2 sekundy? (threshold pro "hráč čeká")
- Je P95 čas generování pro Tricky/Deep pod 5 sekund?
- Je rejection rate pod kontrolou (P95 < 100 odmítnutých kandidátů)?
- Existují duplicity?
- Jsou hodnoty `estimated_solve_time` konzistentní s difficulty labely?

---

Constraints:
- Neměň produkční kód — jen diagnostický skript v `tool/`
- Skript musí být spustitelný přes `dart run tool/generator_audit.dart`
- Výstup musí být čitelný — tabulky, čísla, jasné závěry
- Pokud sandbox nemá Dart SDK, řekni to explicitně

Po dokončení: já spustím skript a pošlu ti výstup. Pak rozhodneme, zda je generátor připravený pro Free Play.
