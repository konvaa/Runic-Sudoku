Diagnostický nástroj odhalil, že problém je hlubší, než jsme čekali. Data z `dart run tool/calibrate_difficulty.dart`:

```
Quick   blanks=36  avg_est=170s   decisions histogram -> 0:100
Normal  blanks=15  avg_est=91s    decisions histogram -> 0:100
Tricky  blanks=19  avg_est=117s   decisions histogram -> 0:100
Deep    blanks=22  avg_est=139s   decisions histogram -> 0:99  1:1
```

I při 60%+ prázdných buněk (Deep fraction) je decision_points_count téměř vždy 0 — tvá nová "stall + solution-assisted" definice je v praxi STEJNĚ vzácná jako ta předchozí ("hidden single in complex state"). To naznačuje, že problém není ve volbě konkrétní definice decision point, ale možná v tom, že na 6×6 gridu (jen 6 hodnot) naked/hidden single technika prakticky vždy stačí k dořešení, bez ohledu na to, kolik se odebere — tj. samotný koncept "stall" může být na 6×6 vzácný jev z podstaty velikosti gridu, ne věc definice.

Druhé pozorování z dat: `avg_est` neroste s obtížností smysluplně (Quick=170s, Normal=91s, Tricky=117s, Deep=139s) — Quick má vyšší avg_est než všechny ostatní. To naznačuje, že `estimated_solve_time` vzorec teď koreluje primárně s `forced_moves_count` (počet odebraných/prázdných buněk), ne s obtížností řešení — víc prázdných buněk = víc forced moves k vyplnění = vyšší T_forced příspěvek, což je opačná logika, než chceme.

Úkol: než znovu měníš konstanty, potřebuju systematické empirické srovnání alternativních přístupů k difficulty modelu na 6×6, s daty, ne jen teorií. Konkrétně:

1. **Změř distribuci "true stall rate" napříč celým rozsahem blank fraction** (ne jen 4 fixed body, ale třeba každých 5%, od 20% do 70%) — kolik % vygenerovaných (před rejection rules) puzzlů na každé úrovni skutečně narazí na stall (naked/hidden single nestačí), bez ohledu na current decision-point definici. To nám řekne, jestli stall vůbec existuje na 6×6 v jakémkoliv rozumném množství, nebo je to v podstatě nikdy.

2. **Vyzkoušej alternativní obtížnostní metriku, která NENÍ založená na "stall", ale na něčem, co se na 6×6 reálně vyskytuje a roste s obtížností.** Konkrétní kandidáti k vyzkoušení a změření (neimplementuj všechny do finální verze, jen je proměř a porovnej):
   - **Solving step count**: prostý počet kroků (naked+hidden singles), které solver musí udělat k dořešení — roste přirozeně s počtem prázdných buněk, jednoduché a měřitelné.
   - **Hidden-single ratio**: podíl hidden single ku naked single krokům. Hidden single obecně vyžaduje víc skenování (hráč musí prohledat celý řádek/sloupec/box, ne jen jednu buňku), takže vyšší podíl by mohl korelovat s vnímanou obtížností i bez "stall".
   - **Max candidates per cell v libovolném bodě řešení**: i bez stall může být kognitivně náročnější puzzle, kde si hráč musí v nějaké chvíli pamatovat/sledovat buňku se 3-4 kandidáty, než puzzle, kde má každá buňka vždy ≤2 kandidáty.
   - Pokud máš jiný nápad založený na něčem, co se na 6×6 reálně měří jako rostoucí s obtížností, přidej ho do srovnání a vysvětli proč.

3. **Pro každou metriku z bodu 2 změř, jak dobře koreluje s blank fraction** (tj. roste metrika monotónně/rozumně s tím, jak ubývá daných buněk?) — to je proxy pro "je tahle metrika použitelná jako difficulty signál".

4. **Napiš krátké doporučení** (ne finální rozhodnutí, to je na nás): která metrika (nebo kombinace) by na 6×6 reálně fungovala jako difficulty signál, a jestli Phase 0 čtyřúrovňový model (Quick/Normal/Tricky/Deep) je na 6×6 vůbec realistický, nebo jestli data naznačují, že 6×6 reálně podporuje míň rozlišitelných úrovní (např. jen 2-3 smysluplně odlišné).

Důležité: tohle je měřicí/diagnostický úkol, ne implementační rozhodnutí. Nepřepisuj `HumanLikeSolver`/`DifficultyScorer` na finální verzi sám — rozšiř `tool/calibrate_difficulty.dart` (nebo vytvoř druhý diagnostický skript), abys mohl tato měření spustit a ukázat mi čísla. Žádnou ze zkoumaných metrik nezaváděj do produkčního kódu, dokud se nedohodneme, kterou použít.

Výstup: tabulka/čísla pro každou metriku přes rozsah blank fraction, plus tvoje doporučení s odůvodněním. Pak společně rozhodneme další krok.
