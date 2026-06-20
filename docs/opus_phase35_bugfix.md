Dva konkrétní bugy k opravě v Phase 3.5 progression systému. Žádné nové funkce, žádné změny scope.

Než cokoliv opravíš, přečti si z disku:
- `lib/games/runic_sudoku/progression.dart`
- `lib/games/runic_sudoku/progression_controller.dart`
- `lib/core/profile/player_profile.dart`
- `lib/core/profile/app_controller.dart`
- `lib/games/runic_sudoku/runic_sudoku_screen.dart` (kde se volá recordProgression / completion)
- `lib/games/runic_sudoku/level_pool.dart` (jak se identifikuje daily level)

---

Bug 1: Daily puzzle completion nesmí ovlivňovat campaign progression

Aktuální chování: dokončení daily puzzle se počítá do `completed_level_ids` v `PlayerProfile`, a tím posouvá chapter progress / odemyká levely v kampani (protože daily je reálný pool level).

Požadované chování: dokončení daily puzzle se NEPOČÍTÁ do campaign progression. Daily a kampaň jsou oddělené systémy — daily má vlastní streak/tracking, ale NESMÍ přidávat do `completed_level_ids` ani `chapter_progress` ani odemykat žádné campaign levely.

Implementace: při záznamu completion v `runic_sudoku_screen.dart` (nebo kdekoliv se volá `recordProgression`/`completeLevel`) rozliš, jestli byl level spuštěný jako daily nebo jako campaign level, a pokud jako daily, NEPŘEDÁVEJ completion do progression systému. `DailyPuzzleSelector`/`LevelPool` by měl poskytovat dostatečný identifikátor pro toto rozlišení. Pokud ne, zdůvodni v Implementation decisions, jak jsi to řešil.

---

Bug 2: Chapter unlock counter se neaktualizuje po dokončení levelů

Aktuální chování: "Normal Seals" (Chapter 2) vyžaduje dokončení 10 Quick Runes levelů. Po dokončení Quick levelů se tento counter vizuálně neaktualizuje / chapter se neodemkne, i když je splněná podmínka.

Diagnostikuj nejdřív:
- Je problém ve výpočtu (unlock podmínka se nepočítá správně po completion)?
- Nebo je problém v UI (podmínka je splněná, ale level select se neobnoví/nepřekreslí)?
- Nebo je problém v persistenci (po restartu appky se chapter odemkne správně, ale v aktuálním běhu ne)?

Podle diagnostiky oprav příčinu, ne symptom. Pokud je to UI refresh problém (ChangeNotifier/setState se nezavolá po completion), oprav notifikaci. Pokud je to výpočetní problém v `Progression.computeUnlockedChapters`, oprav výpočet. Uveď jasně, co bylo příčinou.

---

Po opravě:

1. Přidej/uprav testy:
   - Dokončení daily level NESMÍ přidat do `completedLevelIds` pro progression účely
   - Dokončení dostatečného počtu Chapter 1 levelů MUSÍ odemknout Chapter 2 (a to v aktuálním běhu, ne jen po restartu)

2. Spusť `flutter test` pokud máš sandbox k dispozici; pokud ne, řekni to explicitně.

3. Do Implementation decisions zapiš:
   - Jak jsi identifikoval daily level pro vyloučení z progression
   - Jaká byla konkrétní příčina bug 2 (výpočet / UI refresh / persistence)

Žádné jiné změny — scope je striktně oprava těchto dvou bugů.
