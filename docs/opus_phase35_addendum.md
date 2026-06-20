Doplněk k zadání výše (vlož na začátek, před "Context:"):

Než cokoliv navrhneš, znovu si přečti z disku:
- `lib/core/profile/player_profile.dart`
- `lib/games/runic_sudoku/level_pool.dart`
- `lib/app/level_select_screen.dart`
- `assets/levels/runic_sudoku_levels.json` (aktuální obsah — kolik levelů na label reálně existuje)
- `lib/games/runic_sudoku/generator/level_data.dart` (nebo ekvivalentní export formát)

Pokud cokoliv neodpovídá tomu, co je popsáno níže, zapiš to do Specification ambiguities, nerozhoduj tiše.

---

Doplnění k "Suggested level distribution":

Současný pool má 70 levelů (20 Quick, 20 Normal, 20 Tricky, 10 Deep) — viz `runic_sudoku_levels.json`. Navržená distribuce (20/30/30/20 = 100) je víc, než teď existuje. Vyřeš tohle explicitně, jednou z cest:
- (a) Dogeneruj chybějící levely přes existující `tool/generate_level_pool.dart` (uprav parametry počtu na cílovou distribuci) a commitni nový/rozšířený JSON pool, NEBO
- (b) Pokud dogenerování není v rozsahu tohoto tasku, navrhni distribuci, která sedí na současných 70 levelech (např. 20/20/20/10), a poznamenej rozdíl oproti "suggested" číslům jako Implementation decision.
Preferuju (a), pokud to nevyžaduje změnu generátoru/difficulty modelu samotného (jen spuštění existujícího skriptu s jinými count parametry) — to by mělo být bezpečné a rychlé. Pokud (a) z nějakého důvodu není bezpečné, zvol (b) a vysvětli proč.

---

Doplnění k `progression_version`:

Slouží jako budoucí migrace switch (pro případ, že se progression model později změní, např. při zavedení multi-size). Pro teď stačí konstanta `1` — nepřidávej žádnou migrační logiku, jen pole připravené pro budoucí použití.

---

Doplnění k pojmenování:

Interní kód-jména (`campaignProgress`, `ChapterModel`, atd.) jsou v pořádku jakkoliv pojmenovaná pro čitelnost kódu. Pro display-facing texty (název obrazovky, název kapitol jako "Chapter 1") použij neutrální placeholder texty teď (např. "Chapter 1", "Chapter 2" je v pořádku) — finální hráči viditelné názvy (zvažujeme něco jako "Rune Trials" nebo "Temple Path" místo "Campaign") vybereme později jako copy/content úpravu, ne jako součást tohoto kódového tasku. Nezasekávej se na hledání "správného" jména teď.
