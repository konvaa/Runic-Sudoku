Máme reálná naměřená data z `tool/difficulty_metric_exploration.dart` (ne predikce — skutečný výstup u mě):

```
frac  tgtBlank avgBlank stall%  avgSteps hiddenRatio maxCands complexity
0.20  7        7.0      0.0     7.0      0.000       1.48     0.000
0.25  9        9.0      0.0     9.0      0.000       1.77     0.000
0.30  11       11.0     0.0     11.0     0.000       2.05     0.003
0.35  13       13.0     0.0     13.0     0.000       2.46     0.012
0.40  14       14.0     0.0     14.0     0.000       2.56     0.015
0.45  16       16.0     0.0     16.0     0.000       2.88     0.027
0.50  18       18.0     0.0     18.0     0.000       3.24     0.053
0.55  20       20.0     0.0     20.0     0.001       3.69     0.086
0.60  22       22.0     0.0     22.0     0.003       4.00     0.122
0.65  23       23.0     0.0     23.0     0.011       4.28     0.151
0.70  25       25.0     1.0     24.8     0.037       4.49     0.204

Pearson r vs blank fraction:
  stall_rate        : 0.500
  solving_steps      : 0.999  (but == blank count, [CERTAIN] from your prior analysis — not an independent signal)
  hidden_ratio       : 0.646
  max_candidates     : 0.997
  candidate_complex  : 0.929
```

Rozhodnutí na základě těchto dat: stall/decision_points_count se na 6×6 zahazuje jako primární difficulty signál (potvrzeno: stall rate je 0.0–1.0 % v celém měřeném rozsahu — fenomén na 6×6 prakticky neexistuje). Nahrazujeme ho `candidate_complexity` jako primárním signálem, případně v kombinaci s `max_candidates`. `decision_points_count`/stall koncept zůstává v kódu jako pole/typ (kvůli budoucí kompatibilitě s případným 9×9), ale přestává být to, na čem visí rejection rules a label assignment pro 6×6.

Úkol — přepracuj difficulty model, konkrétně:

1. **Nový primární difficulty signál**: použij `candidate_complexity` (vzorec z Phase 0 sekce 3.1, normalizovaný 0.0–1.0) jako hlavní osu pro label assignment. Pokud chceš kombinovat s `max_candidates` pro lepší rozlišení mezi blízkými hodnotami, zdůvodni to a ukaž, jak kombinace zlepšuje rozlišovací schopnost oproti `candidate_complexity` samotnému — neimplementuj kombinaci jen proto, že je dostupná.

2. **Nové label thresholdy založené na naměřených datech.** Z tabulky výše: `candidate_complexity` má užitečný, monotónně rostoucí rozsah od 0.000 (frac 0.20) do 0.204 (frac 0.70). Navrhni konkrétní hraniční hodnoty pro labely. Nepředpokládej, že musí zůstat 4 labely (Quick/Normal/Tricky/Deep) — pokud data naznačují, že 2-3 úrovně jsou realističtější rozlišení (jak jsi sám navrhoval), navrhni to, ale jasně to odůvodni na základě toho, jak rozlišitelné jsou sousední complexity hodnoty (např. pokud je rozdíl mezi "Tricky" a "Deep" pásmem menší než šum/variance při stejné blank fraction, je to slabý důvod merge).

3. **Přepracuj `estimated_solve_time` vzorec.** Současný vzorec (`forced_moves_count * T_forced + decision_points_count * T_decision + candidate_complexity * T_complexity_modifier`) je teď z velké části jen `blank_count * T_forced`, protože decision_points_count ≈ 0 vždy. To je důvod, proč Quick měl vyšší avg_est než Deep — to je obrácená logika. Navrhni vzorec, kde `candidate_complexity` má větší váhu na celkový odhad, a `forced_moves_count`/blank count přestává dominovat. Nemusí to být složitý vzorec — i jednoduchý `base_time + candidate_complexity * scaling_factor` je v pořádku, pokud dává smysluplné pořadí (Quick < Normal < Tricky < Deep v odhadovaném čase, ne obráceně). Validuj to na datech z tabulky výše — spočítej, jaký by `estimated_solve_time` vyšel pro každou frac hodnotu s novým vzorcem, a ukaž, že pořadí sedí.

4. **Aktualizuj rejection rules** (Section 3.1/5 z Phase 0) tak, aby odkazovaly na nový primární signál, ne na `decision_points_count == 0`. Zachovej `unsupported_technique` flag a jeho účel (puzzle, které MVP solver nedokáže vyřešit vůbec — to se nemění, je to nezávislé na difficulty modelu).

5. **`decision_points_count`/stall pole nezahazuj z kódu úplně** — necht zůstane jako vedlejší metrika v `HumanLikeResult` (může být relevantní pro budoucí 9×9, kde stall podle tebe reálně nastává), ale nesmí být součástí rejection rules ani label assignment pro 6×6.

Co NEDĚLAT:
- Neměň `unsupported_technique` logiku (stall detekce pro "nevyřešitelné MVP technikami" zůstává, to je jiný koncept než difficulty stupňování).
- Nepřidávej nové solving techniky (pointing pairs apod.) — to je mimo scope.
- Neimplementuj 9×9 podporu — jen nezavírej dveře (parametričnost zůstává).

Po implementaci:
- Spusť `flutter test` a `dart run tool/calibrate_difficulty.dart` (případně ho uprav, pokud teď měří nesprávnou metriku) a potvrď, že všechny zvolené labely jsou generovatelné v rozumném počtu pokusů.
- Aktualizuj `PHASE2_NOTES.md`: zdokumentuj tuto změnu jako novou položku v Implementation decisions (proč candidate_complexity, s odkazem na naměřená data, ne predikce), a označ, jestli je nový model i tak ještě k review, nebo jestli ho považuješ za stabilní.
- Pokud narazíš na to, že i s novým modelem některý label zůstává nedosažitelný nebo nespolehlivý, řekni to přímo s daty — neschovávej to za "funguje to teď", pokud čísla říkají jinak.
