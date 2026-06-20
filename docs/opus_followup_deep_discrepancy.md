Výsledky z `calibrate_difficulty.dart` neodpovídají tvému tvrzení v textu. Napsal jsi: "Deep na 6×6 korektně vyhodí výjimku (nedosažitelné)" a že `DifficultyLabel.deep` se na 6×6 "nikdy nevygeneruje". Ale reálný výstup nástroje ukazuje:

```
Deep    ok=9/10  avgAttempts=22.2  avgComplexity=0.320  avgBlanks=27.0  avgEst=413s
```

To je 9 úspěšných generací z 10 běhů (jen 1 selhání na 60 maxAttempts), ne "nedosažitelné". Vyjasni prosím tenhle nesoulad, než to uzavřeme:

1. Je `calibrate_difficulty.dart` aktuální vůči finální verzi `PuzzleGenerator`/`DifficultyScorer`, nebo testuje jinou cestu (např. starší fallback, nebo přímo carving na vysoké blank fraction bez plného rejection-rule řetězce, kterým by reálná hra Deep generovala)?

2. Pokud je nástroj správně napojený na produkční kód: oprav svoje tvrzení v `PHASE2_NOTES.md` — Deep na 6×6 JE dosažitelný, jen s výrazně vyšší cenou (22× víc pokusů než Quick/Normal/Tricky, a ~90% úspěšnost při 60 pokusech). To je jiný závěr než "nedosažitelné", a má to dopad na rozhodnutí, jestli Deep nabízet hráčům na 6×6 vůbec (pomalá generace na klientovi by mohla být postřehnutelná, 10% selhání by potřebovalo plán B — např. fallback na Tricky, nebo vyšší maxAttempts).

3. Pokud byl tvůj výrok "nedosažitelné" založen na něčem, co jsi nemohl ověřit (sandbox byl nedostupný), řekni to explicitně — to je v pořádku, jen to potřebuju vědět, abych nepracoval se závěrem, který se ukázal nesprávný.

4. Doporuč: má smysl Deep na 6×6 nabízet v produkci (s vyšší cenou generace, případně předgenerovat a cachovat místo on-demand), nebo doporučuješ Deep skutečně vyřadit z 6×6 nabídky a nechat ho jen jako schéma pro budoucí větší grid? Tohle je rozhodnutí, které chci udělat s opraveným, přesným obrazem dat — ne s tvrzením, které si navzájem neodpovídá s naměřeným výstupem.

Neměň kód, dokud nevyjasníš bod 1 — jen vysvětli rozpor a navrhni další krok.
