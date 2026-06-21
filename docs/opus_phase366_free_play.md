Phase 3.66 — Free Play Mode.

Než cokoliv navrhneš, přečti si z disku:
- `lib/games/runic_sudoku/generator/puzzle_generator.dart`
- `lib/games/runic_sudoku/generator/difficulty_scorer.dart`
- `lib/games/runic_sudoku/generator/difficulty_constants.dart`
- `lib/games/runic_sudoku/progression.dart`
- `lib/core/profile/player_profile.dart`
- `lib/core/profile/app_controller.dart`
- `lib/app/main_menu_screen.dart`
- `lib/app/level_select_screen.dart`
- `lib/games/runic_sudoku/runic_sudoku_screen.dart`
- `lib/games/runic_sudoku/chapter_theme.dart`

---

## Kontext

Hra má 100 levelů v kampani (Quick Runes / Normal Seals / Tricky Glyphs / Deep Chambers). Po dokončení kampaně nebo i dříve hráč potřebuje možnost hrát bez omezení obsahu. Free Play je on-demand generování nových puzzle — využívá existující `PuzzleGenerator`, nepřidává nový obsah ani progression logiku.

**Důležité upřesnění k obtížnosti:** audit ukázal, že Deep má téměř vždy `decision_points = 0` — Deep je tedy hlavně hustší, méně vodící a vizuálně náročnější puzzle, ne nutně logicky hlubší než Tricky. Free Play to nijak neopravuje — jen to nevypočítávej jako "logická hloubka" v UI popiscích. Obtížnostní labely (Quick/Normal/Tricky/Deep) jsou dostatečné.

---

## Generátor — guardrails (nová rejection rules)

Přidej do generátoru (nebo do post-generation validation) tyto dodatečné podmínky. Pokud puzzle nesplní podmínky, generátor ho zamítne a zkusí znovu (stejný mechanismus jako stávající rejection rules):

**Pro Quick a Normal:**
- Žádný kompletně prázdný řádek (všech 6 buněk = 0)
- Žádný kompletně prázdný sloupec (všech 6 buněk = 0)

**Pro Tricky a Deep:**
- Maximálně jeden kompletně prázdný řádek nebo sloupec celkem (ne jeden řádek A jeden sloupec — celkový součet prázdných řádků + prázdných sloupců ≤ 1)
- Žádný kompletně prázdný 2×3 box (všech 6 buněk v boxu = 0)
- Musí existovat alespoň jeden "jasný první tah" — tj. alespoň jedna buňka, která má po candidate generation pouze 1 kandidáta (naked single dostupný od začátku). Hráč nesmí otevřít board bez zjevného místa kde začít.

Tyto podmínky platí pouze pro Free Play generování. Existující kampaňové puzzle (`assets/levels/runic_sudoku_levels.json`) se nemění.

---

## Free Play unlock

Free Play se odemkne po dokončení **Chapter 1 (Quick Runes)** — tedy po dokončení alespoň 10 Quick Runes levelů (stávající chapter unlock threshold). Ne až po dokončení celé kampaně.

Uložit do `PlayerProfile` jako `freePlayUnlocked: bool` — odvozeno z `completedLevelIds` (pokud jsou splněny podmínky Chapter 1 unlock), nebo persistováno přímo. Zvol čistší variantu a zdůvodni v Implementation decisions.

---

## UI — Free Play vstup

Na `main_menu_screen.dart` přidej třetí tlačítko pod "Rune Trials":

```
[ Daily Puzzle ]     🔥 1 day streak
[ Rune Trials  ]
[ Free Play    ]     (zamčené pokud !freePlayUnlocked)
```

- Zamčené tlačítko: zobrazit s ikonkou zámku + tap = snackbar/dialog "Complete Quick Runes chapter to unlock"
- Odemčené tlačítko: naviguje na `FreeDifficultySelectScreen`

---

## FreeDifficultySelectScreen

Nová jednoduchá obrazovka: hráč vybere obtížnost.

```
       Free Play

   Choose your difficulty:

   [ ⚡ Quick    ~1 min  ]
   [ 📜 Normal   ~2 min  ]
   [ 💎 Tricky   ~5 min  ]
   [ 🌑 Deep     ~7 min  ]
```

- Orientační časy jsou fixní popisky (ne z `estimated_solve_time`) — jednoduché a srozumitelné
- Každé tlačítko spustí generování a přechod na `RunicSudokuScreen`
- Background: použij `default_rune_bg.png` (stejně jako level select)

---

## Generování a loading overlay

Generování probíhá **mimo UI thread** (Dart `Isolate` nebo `compute()`). Během generování zobraz loading overlay:

```
     ⚙  Preparing your trial...
```

- Overlay se zobrazí **okamžitě po výběru obtížnosti**, ne až po zamrznutí UI
- Tmavý poloprůhledný overlay (stejný styl jako HUD panel — `Colors.black` @ 0.75–0.8)
- Jednoduchý text, žádný progress bar (délka generování není předem známá)
- Quick/Normal/Tricky: generování trvá < 10ms, overlay bude vidět jen zlomek sekundy — to je OK, lepší než žádný feedback
- Deep: může trvat až ~750ms na PC, na slabším Androidu déle — overlay je zde skutečně potřebný

Po dokončení generování: přejdi přímo na `RunicSudokuScreen` s vygenerovaným puzzle.

Pokud generování selže (maxAttempts vyčerpáno — velmi vzácné u Deep): zobraz chybový dialog "Could not generate a puzzle. Please try again." a vrať se na difficulty select.

---

## Herní smyčka Free Play

Po dokončení puzzle (win screen "Solved!"):
- Zobraz výsledky (čas, chyby, hinty) — stejný dialog jako kampaň
- Přidej tlačítko **"Next Trial"** vedle/pod "Continue"
- "Next Trial" spustí generování dalšího puzzle stejné obtížnosti (s loading overlay)
- "Continue" vrátí na main menu

Free Play nesmí:
- Měnit chapter progression v kampani
- Interferovat s Daily Puzzle
- Ukládat individuální Free Play puzzle do `completed_level_ids` (ty jsou jen pro kampaň)

---

## Statistiky Free Play

Ukládej do `PlayerProfile` (nová pole):
- `freePlays_completed: int` — celkový počet dokončených Free Play puzzle
- `freePlays_best_times: Map<String, int>` — nejlepší čas (sekundy) per difficulty label
- `freePlays_current_streak: int` — počet po sobě jdoucích dokončených Free Play puzzle (bez opuštění)

Žádné lifetime leaderboardy, žádné sdílení, žádná serverová data.

---

## Testy

Přidej testy pro:
- Guardrails: Quick/Normal puzzle nemá prázdný řádek ani sloupec
- Guardrails: Tricky/Deep puzzle má maximálně jeden prázdný řádek/sloupec celkem
- Guardrails: Tricky/Deep puzzle nemá kompletně prázdný 2×3 box
- Guardrails: každé puzzle má alespoň jeden naked single od začátku
- Free Play unlock: `freePlayUnlocked` je false pokud Chapter 1 není dokončena, true pokud ano
- Free Play statistiky: `freePlays_completed` se inkrementuje po dokončení, `freePlays_best_times` se aktualizuje pokud je čas lepší

Existující testy musí projít beze změny.

---

## Constraints

- Neměň kampaňové puzzle (`assets/levels/runic_sudoku_levels.json`)
- Neměň Daily Puzzle logiku
- Neměň chapter progression pravidla
- Nepřidávej energy/lives/timers/ekonomiku
- Interstitial ad po Free Play puzzle: stejná frekvence jako po kampaňových levelech (každý 3. level complete) — použij existující `MonetizationPolicy`, neměň ji
- Hint a mistake check: stejné chování jako v kampani

---

## Výstup

1. Architektonický plán
2. Nové/upravené soubory
3. Implementace
4. Testy
5. Implementation decisions I made
6. Not implemented / deferred ideas
7. Specification ambiguities
