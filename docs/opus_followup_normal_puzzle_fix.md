flutter test odhalil reálný problém, ne flaky test:

```
Bad state: Failed to generate a Normal puzzle within 300 attempts. Tune DifficultyTuning or raise maxAttempts.
```

Než cokoliv ladíš, nejdřív diagnostikuj, ne jen zvyš maxAttempts nebo přelaď konstanty natvrdo:

1. Zjisti, jak často (z kolika pokusů) generátor reálně produkuje puzzle s `decision_points_count >= 1` na 6×6 gridu se současnou decision-point definicí (N=3 threshold, hidden single v komplexním stavu). Pokud je to extrémně vzácné i mimo testovací limit (300), je to signál, že buď N=3 je na 6×6 prostoru příliš striktní, nebo `targetBlankFraction` pro Normal (0.33) nedává generátoru dost prázdných buněk, aby se komplexní stav vůbec vytvořil.

2. Měř a krátce shrň: jaký je reálný rozsah `decision_points_count` přes řekněme 50-100 vygenerovaných kandidátů na Normal blank fraction, předtím než se aplikují rejection rules? To mi řekne, jestli je problém v threshold N, v blank fraction, nebo v obojím.

3. Na základě toho navrhni opravu — ale BEZ změny zadání/scope. Validní opravy v pořadí preference:
   - Uprav `targetBlankFraction` pro Normal/Tricky/Deep tak, aby generátor reálně dosahoval cílového decision_points_count rozsahu (je to jen tuning konstanta, ne architektonická změna).
   - Pokud to nestačí, zvaž úpravu N (decision-point threshold) — ale jen pokud to zdůvodníš měřením, ne odhadem.
   - Pokud ani jedno nepomůže a problém je fundamentální (6×6 prostor je prostě moc malý na to, aby "hidden single v komplexním stavu" definice produkovala dost Normal/Tricky/Deep puzzlů spolehlivě), řekni to přímo a navrhni, jestli decision-point definice potřebuje širší revizi (např. zahrnout i naked single v komplexním stavu, ne jen hidden single) — to by byla změna k diskuzi, ne k tichému zavedení.

Po opravě: spusť `flutter test` znovu, potvrď že všechny difficulty labely (Quick/Normal/Tricky/Deep) jsou generovatelné v rozumném počtu pokusů (ne 300 na hraně), a aktualizuj `PHASE2_NOTES.md` s tím, co jsi zjistil a změnil — včetně toho, jestli je teď decision-point definice/kalibrace připravená na review, nebo pořád otevřená.

Mimo to: smaž nebo oprav `test/widget_test.dart` — odkazuje na neexistující `MyApp` konstruktor (zbytek z `flutter create .` scaffoldingu), nesouvisí s Phase 1/2 a blokuje to čistý `flutter test` běh.
