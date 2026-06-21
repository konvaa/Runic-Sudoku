Phase 3.66.2 — Free Play Session Persistence.

Než cokoliv navrhneš, přečti si z disku:
- `lib/core/save/save_service.dart`
- `lib/core/save/local_save_repository.dart`
- `lib/games/runic_sudoku/runic_sudoku_screen.dart`
- `lib/games/runic_sudoku/runic_sudoku_controller.dart`
- `lib/games/runic_sudoku/runic_sudoku_snapshot.dart`
- `lib/core/profile/player_profile.dart`
- `lib/app/free_play_screen.dart` (Free Play UI)
- `lib/games/runic_sudoku/freeplay/deep_free_play_cache.dart`

---

## Problém

Free Play puzzle se aktuálně neukládá při přerušení (force-stop, systémový kill, telefon zazvoní). Hráč může mít rozehraný Deep trial 5–8 minut a přijít o vše. To je stejná chyba jako neukládat kampaňový level.

---

## Tři oddělené save sloty

Existující systém má jeden aktivní level slot per game. Rozšiř ho na tři explicitní sloty:

```
activeCampaignSession   →  saveKey: "runic_sudoku/active_campaign"
activeDailySession      →  saveKey: "runic_sudoku/active_daily"  
activeFreePlaySession   →  saveKey: "runic_sudoku/active_freeplay"
```

Každý slot je nezávislý — žádný nesmí přepsat jiný. Kampaňový puzzle zůstane uložený i když hráč přejde do Free Play a naopak.

**Stávající save klíče** (zjisti z kódu co se aktuálně používá) musí zůstat kompatibilní — pokud existující kampaňový save používá jiný klíč, nemigruj ho, jen přidej nové sloty pro daily a freeplay.

---

## Free Play snapshot schema

`RunicSudokuSnapshot` rozšiř o pole pro rozlišení módu (pokud tam ještě není):

```dart
enum PuzzleMode { campaign, daily, freePlay }
```

Free Play snapshot musí obsahovat minimálně:
- `mode: PuzzleMode.freePlay`
- `difficulty_label` (Quick/Normal/Tricky/Deep)
- `puzzleId` (pro Deep: `idx_N` z bundled poolu nebo hash; pro Quick/Normal/Tricky: hash z `given_cells`)
- `solution_grid`
- `given_cells`
- `current_grid`
- `notes_grid`
- `mistakes_count`
- `hints_used`
- `elapsed_time`
- `started_at`
- `last_saved_at`

---

## Save triggery pro Free Play

Free Play puzzle ukládej na stejné triggery jako kampaňový level:
- `placement_complete`
- `notes_changed`
- `hint_used`
- `mistake_checked`
- `level_complete` (po dokončení: smaž `activeFreePlaySession`, ulož jen statistiky)
- `app_pause`

---

## Obnova rozehrané Free Play session

Při otevření Free Play obrazovky (`FreeDifficultySelectScreen` nebo ekvivalent):
- Zkontroluj jestli existuje `activeFreePlaySession` snapshot
- Pokud ano: zobraz dialog/banner "Continue your [Difficulty] trial? (time elapsed)" s tlačítky "Continue" a "New Trial"
- "Continue" → načti snapshot a pokračuj
- "New Trial" → smaž `activeFreePlaySession`, generuj nové puzzle
- Pokud ne: rovnou na výběr obtížnosti

---

## Dokončení Free Play

Po `level_complete`:
1. Zobraz win dialog (čas, chyby, hinty) — stejný jako kampaň
2. Smaž `activeFreePlaySession` z SharedPreferences
3. Aktualizuj Free Play statistiky v `PlayerProfile` (`freePlaysCompleted`, `freePlays_best_times`, `freePlays_current_streak`)
4. Tlačítko "Next Trial" → generuj nové puzzle stejné obtížnosti (žádný "continue" dialog — session byla dokončena)
5. Tlačítko "Continue" → main menu

---

## Constraints

- Kampaňový save (`activeCampaignSession`) nesmí být nikdy přepsán Free Play operacemi
- Daily save (`activeDailySession`) nesmí být nikdy přepsán Free Play operacemi
- Free Play nesmí měnit `completed_level_ids` v `PlayerProfile` (to je jen pro kampaň)
- Free Play snapshot se smaže po dokončení puzzle — neakumuluj historii dokončených Free Play snapshotů
- Neměň existující kampaňový ani daily save flow

---

## Testy

- `activeFreePlaySession` se uloží po `placement_complete`
- `activeFreePlaySession` se obnoví po simulovaném restartu (SharedPreferences mock)
- `activeFreePlaySession` se smaže po `level_complete`
- `activeCampaignSession` není ovlivněn Free Play save operacemi
- "Continue trial" dialog se zobrazí pokud existuje `activeFreePlaySession`
- "New Trial" smaže existující session a vytvoří novou
- Statistiky se aktualizují po dokončení Free Play puzzle

Existující testy musí projít beze změny.

---

## Výstup

1. Architektonický plán
2. Nové/upravené soubory
3. Implementace
4. Testy
5. Implementation decisions I made
6. Not implemented / deferred ideas
7. Specification ambiguities

Spusť `flutter test` + `flutter analyze` pokud máš sandbox; pokud ne, řekni explicitně.
