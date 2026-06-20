Vytvoř implementační návrh a kód pro Phase 3 — Product MVP — podle Phase 0 specifikace (sekce 7, 9, 10, 12) a na základě existující Phase 1/2 kostry (`/lib/app`, `/lib/core`, `/lib/grid`, `/lib/games/runic_sudoku`, `assets/levels/runic_sudoku_levels.json`).

Než cokoliv navrhneš, znovu si přečti z disku (ne z paměti konverzace):
- `lib/app/level_select_screen.dart`, `lib/app/settings_screen.dart`, `lib/app/main_menu_screen.dart`
- `lib/core/ads/ads_service.dart` a jeho no-op implementaci
- `lib/core/purchases/purchase_service.dart` a jeho no-op implementaci
- `lib/core/analytics/analytics_service.dart` a jeho no-op implementaci
- `lib/games/runic_sudoku/runic_sudoku_controller.dart`
- `lib/games/runic_sudoku/solver/solver_step.dart` (pro hint napojení na `solver_steps_log`)
- `assets/levels/runic_sudoku_levels.json` (skutečná struktura level poolu, 70 levelů)
- `PHASE2_NOTES.md` (zejména finální stav `LevelData`/`HumanLikeResult`)

Pokud cokoliv z výše uvedeného neodpovídá tomu, co je popsáno níže, nerozhoduj tiše — zapiš to do "Specification ambiguities" stejně jako v předchozích fázích.

---

Důležité omezení — co Phase 3 NENÍ:
- **Není to integrace reálného AdMob/Unity Ads SDK ani Google Play Billing/StoreKit.** `AdsService`/`PurchaseService` zůstávají na no-op implementacích z Phase 1 (ty už vrací validní `AdResult`/`PurchaseResult` typy). Phase 3 řeší **UI a herní logiku, která tyto služby volá**, ne samotné SDK. Reálná SDK integrace je explicitně budoucí fáze (Phase 4+), mimo tento task.
- **Není to redesign vizuálu/theme.** Theme/RuneSet systém z Phase 1 zůstává — jeden výchozí Theme, jeden RuneSet. Žádné nové vizuální assety, žádný ASO balíček (to je samostatný, paralelní úkol mimo kód).
- **Není to denní generování nového puzzle za běhu.** Daily puzzle vybírá konkrétní level **z existujícího pre-generated poolu** (`runic_sudoku_levels.json`) podle deterministického pravidla vázaného na datum — nevolá `PuzzleGenerator` na zařízení.
- **Žádný backend/server.** Daily puzzle rotace, streak, a všechny ostatní mechaniky jsou čistě klientské (lokální datum + lokální save data).

---

Cíl tasku — pět oblastí:

### 1. Level Select (navazuje na existující `level_select_screen.dart` shell)

- Čte levely z `assets/levels/runic_sudoku_levels.json` (jednorázově při startu nebo lazy, podle toho, co je v `pubspec.yaml` už zaregistrované).
- Zobrazuje levely seskupené nebo filtrovatelné podle `difficulty_label` (Quick/Normal/Tricky/Deep).
- Pro každý level zobraz aspoň: difficulty label, stav dokončení (pokud je v save datech `completed = true` pro daný `level_id`), a basic vizuální odlišení dokončených/nedokončených/zamčených (pokud zavádíš zamykání — viz bod "Implementation decisions" níže, kde to máš zdůvodnit, ne přidat automaticky).
- Tap na level → naviguje do `RunicSudokuScreen` s daným levelem načteným.

### 2. Daily Puzzle

- Implementuj deterministický výběr "puzzle dne" z existujícího poolu: stejné kalendářní datum (lokální čas zařízení) → stejný level pro všechny hráče. Použij datum jako seed pro deterministický index do poolu (např. hash data → index modulo počet levelů v poolu, nebo modulo počet levelů konkrétního labelu, pokud chceš denní puzzle vázat na konkrétní obtížnost — rozhodni a zdůvodni).
- App Core má už "daily challenge shell" (Section 7) — naváž na něj, neduplikuj logiku menu/navigace.
- `daily_streak` (z App Core profilu, Section 10) se zvyšuje při dokončení daily puzzle ve správný den, resetuje se při zmeškání dne. Definuj přesně, co znamená "zmeškání" (např. token "last_played_date" + kontrola souvislosti).

### 3. Hint System (UI napojení na `solver_steps_log`)

- Hint tlačítko v `RunicSudokuScreen`/`RunicSudokuController` teď používá `solver_steps_log` z `HumanLikeResult` (vygenerovaného při tvorbě levelu, uloženého jako součást `LevelData` nebo dopočítaného při loadu — rozhodni, kde se to uloží/cachuje, a zdůvodni) k tomu, aby ukázal **další logický krok řešení**, ne jen libovolnou prázdnou buňku ze `solution_grid` (to byl Phase 1 placeholder, teď ho nahrazuješ).
- Hint flow: tap na hint → zavolat `AdsService.showRewardedAd()` → na `AdResult` s `rewardGranted == true` → odhalit buňku z dalšího nepoužitého kroku v `solver_steps_log` → zapsat `hints_used += 1` a uložit snapshot s `trigger_type = hint_used`.
- Pokud `solver_steps_log` pro daný level chybí nebo je již celý vyčerpaný (všechny kroky odhaleny), navrhni rozumné fallback chování (např. odhalit jakoukoliv správnou prázdnou buňku ze `solution_grid`) a zdokumentuj to jako "Implementation decision", ne tichý hack.

### 4. Mistake Check

- Implementuj podle Phase 0 rozhodnutí (Section 10): 1 free check per puzzle, další za rewarded ad. Free check se sleduje per-snapshot (nové pole, pokud `mistakes_count`/existující schema nestačí — pokud potřebuješ nové pole, zapiš to do ambiguities, protože to je odchylka od Phase 0 sekce 6.3 schema).
- Check zvýrazní (ne odstraní) buňky, které nesouhlasí se `solution_grid` — to už je podle Phase 1 implementace ("Check" action), jen ho teď napoj na free/rewarded logiku.

### 5. Monetizace — wiring, ne SDK

- **Interstitial**: zobraz (zavolej `AdsService.showInterstitial()`) jen na přechodu mezi levely (po `level_complete`, před návratem na level select), nikdy uprostřed aktivní hry. Implementuj frekvenční limit (Section 10: "po 2-3 interstitials od posledního offer") jako počítadlo v App Core profilu.
- **Remove-ads offer**: implementuj trigger logiku z Section 10 — needs `completed_levels_count` a session duration tracking (pravděpodobně už existuje v App Core analytics, ověř). První nabídka po malém počtu levelů NEBO minimální době hraní (zvol konkrétní výchozí hodnoty, např. "5 levelů NEBO 10 minut", zdůvodni). Po `remove_ads_purchased == true`: žádné další interstitially, rewarded ads zůstávají dostupné.
- **Settings screen**: doplň manuální "Remove Ads" vstup (vždy dostupný, nezávisle na trigger logice).
- **Analytics**: zajisti, že všechna pole ze Section 10 (`sessions_count`, `completed_levels_count`, `interstitial_shown_lifetime`, `rewarded_shown_lifetime`, `remove_ads_offer_shown_count`, `remove_ads_purchased`, `first_open_timestamp`, `last_played_date`, `daily_streak`) se aktualizují přes existující `save(snapshot, trigger_type)` mechanismus a odpovídající triggery.

---

Acceptance criteria (z Phase 0 Section 12, Phase 3) — tohle je tvůj cílový checklist, ne návrh:

- [ ] Level select screen lists levels with difficulty labels
- [ ] Daily puzzle is available and resets on schedule
- [ ] Rewarded hint flow works end-to-end (ad → reveal cell from `solver_steps_log`)
- [ ] Remove-ads purchase flow works and persists `remove_ads_purchased = true`
- [ ] Settings screen accessible, includes manual remove-ads entry point
- [ ] Basic analytics events fire for all required fields
- [ ] No interstitial ad is shown while a puzzle is in an active (incomplete, in-progress) state
- [ ] Core gameplay works fully offline; only ads and purchases require connectivity

(ASO asset package je mimo scope tohoto kódového tasku — to řešíme paralelně, ne v kódu.)

---

Testy — minimálně:

- Daily puzzle: stejné datum → stejný level (deterministicky), různá data → různé levely (rozumný rozptyl, ne triviální stejný level pro celý měsíc)
- Hint: odhalí buňku odpovídající dalšímu kroku v `solver_steps_log`, ne náhodnou
- Mistake check: první check v puzzlu je free, druhý a další vyžaduje `rewardGranted == true` z `AdsService`
- Remove-ads trigger: simuluj `completed_levels_count` přes threshold → ověř, že se nabídka "chce zobrazit" (testuj rozhodovací logiku samostatně od UI, ne přes celý widget strom)
- Interstitial frekvence: simuluj N po sobě jdoucích `level_complete` → ověř, že interstitial se nezobrazuje při každém, jen podle limitu

---

Výstup (stejný formát jako Phase 1/2):

1. Architektonický plán.
2. Datové modely (nové/upravené).
3. Kódová kostra.
4. Testy.
5. Co záměrně není implementováno a proč.
6. Implementation decisions I made.
7. Not implemented / deferred ideas.
8. Specification ambiguities.

---

Anti-drift pravidla (stejná jako dřív):
- Žádné nové externí dependencies bez zdůvodnění (proč nutné, co by bylo složitější bez ní, proč není overkill).
- Žádná reálná SDK integrace (AdMob/Billing) — zůstává no-op, jen propojené s herní logikou.
- Žádný redesign Theme/RuneSet/vizuálu.
- Žádné runtime generování nových puzzlů — jen čtení z existujícího poolu.
- Pokud najdeš nesoulad mezi tímto promptem, Phase 0 specifikací, nebo aktuálním stavem kódu na disku, zapiš to do Specification ambiguities, nerozhoduj tiše.

Po dokončení: spusť `flutter test` a `flutter analyze` sám, pokud máš sandbox k dispozici; pokud ne, řekni to explicitně (jak jsi dělal v Phase 2) a já to ověřím u sebe.
