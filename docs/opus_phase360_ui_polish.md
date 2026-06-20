Phase 3.60 — UI Visual Polish. Čistě vizuální task, žádné změny gameplay logiky, progression, solver, generator ani monetizace.

Než cokoliv navrhneš, přečti si z disku:
- `lib/games/runic_sudoku/runic_sudoku_screen.dart` (celý soubor — HUD, AppBar, input panel)
- `lib/app/main_menu_screen.dart`
- `lib/app/level_select_screen.dart`
- `lib/app/settings_screen.dart`
- `lib/games/runic_sudoku/rune_input_panel.dart` (nebo ekvivalentní soubor pro rune input tlačítka)
- `lib/games/runic_sudoku/chapter_theme.dart` (ChapterBackground widget)

---

Kontext a problém:

Hra má per-chapter pozadí (tmavá fantasy ilustrace za gridem). HUD nad gridem (čas, chyby, hinty) je aktuálně jen text bez vlastního podkladu — na tmavém detailním pozadí (kámen, krystaly, magie) je tento text prakticky nečitelný. Přiložený screenshot ukazuje konkrétně: čas "01:29" vlevo se ztrácí v tmavém kamenném pozadí.

Zesvětlení barvy textu nestačí — na každém chapter backgroundu by byl problém jiný (Stone Hall hnědá vs Crystal Cave modrá vs Arcane Depths fialová). Správné řešení je vlastní kontrastní podklad pro HUD.

---

Úkol — 4 oblasti:

**1. Tmavý AppBar + systémové lišty**

Přepni AppBar na tmavý styl konzistentně přes všechny obrazovky:
- puzzle screen, level select, settings
- AppBar background: velmi tmavá barva (blízká `#0D0D0D` nebo `Colors.black87`), nebo průhledný s tmavým gradientem shora
- Titulek a šipka zpět: světlá barva (`Colors.white` nebo zlatá `#E0A94A`)
- `SystemChrome.setSystemUIOverlayStyle` nastavit na dark (světlé ikony statusbaru) konzistentně
- Main menu AppBar nemá (správně) — tam ponechat jak je

**2. Nový kontrastní HUD panel nad gridem**

Nahraď současný nečitelný HUD řádek novým `PuzzleHudWidget` (nebo ekvivalentní název):
- Vlastní tmavý poloprůhledný podklad: `Colors.black` s opacity 0.75–0.85, nebo `BoxDecoration` s tmavým fill + jemný zlatý/šedý outline
- Tři bloky vedle sebe: `⏱ 01:29` | `✕ 0` | `💡 0` (čas, chyby, hinty)
- Světlý text (bílý nebo `#F2EAD8`), malé ikonky před hodnotou
- Panel musí být čitelný na všech čtyřech chapter pozadích (tmavě hnědá, hnědá, modrá, fialová) — tmavý poloprůhledný fill toto garantuje bez závislosti na konkrétní barvě pozadí
- Drž panel kompaktní — nesmí zabírat příliš místa nad gridem

Vizuální referenční layout:
```
[ ← ]              Quick

┌──────────────────────────────────┐
│  ⏱ 01:29     ✕ 0      💡 0      │
└──────────────────────────────────┘

        [ SUDOKU GRID ]
```

**3. Rune input panel — tmavší styling**

Současné rune input tlačítka jsou světle růžové/béžové — neladí s tmavým fantasy pozadím.
- Změň fill na tmavý: `Colors.black54` nebo `Color(0xFF1A1208)` (velmi tmavá hnědá)
- Nebo průhledný s zlatým outline: `Colors.transparent` + `BorderSide(color: Color(0xFFE0A94A))`
- Rune symboly samotné: zlatá nebo světlá barva místo tmavé na světlém
- Smazat/delete tlačítko: stejný styl jako rune buttony
- Bílý grid samotný NECHEJ — ten funguje a je záměrně kontrastní

**4. Přejmenování "Campaign" na "Rune Trials"**

Jednořádková textová změna:
- `lib/app/main_menu_screen.dart`: tlačítko "Campaign" → "Rune Trials"
- `lib/app/level_select_screen.dart`: pokud je někde nadpis/titulek "Campaign" → "Rune Trials"
- Interní kód-jména (`campaignProgress`, `ChapterId` atd.) NEMEŇ — jen display text viditelný hráčem

---

Constraints:
- Bílý grid (sudoku plocha) NECHEJ světlý — záměrný kontrast, funguje
- Neměň herní logiku, progression, save, hint flow, monetizaci
- Neměň ChapterBackground widget samotný (pozadí funguje)
- Nepřidávej animace
- Nepřidávej nové assety
- Neměň barvy/styl main menu (ten byl právě upraven a funguje)

---

Po dokončení:
- Spusť `flutter test` — všechny existující testy musí projít (čistě vizuální změny nesmí rozbít logiku)
- Spusť `flutter analyze`
- Uveď v Implementation decisions:
  - Jak jsi implementoval HUD panel (vlastní widget nebo inline)
  - Jakou barvu/opacity jsi zvolil pro HUD podklad a proč
  - Jak jsi řešil tmavý AppBar konzistentně (globální theme nebo per-screen)
  - Co jsi zvolil pro rune input styling
- Specification ambiguities: pokud globální ThemeData ovlivnila něco nečekaně, zapiš to
