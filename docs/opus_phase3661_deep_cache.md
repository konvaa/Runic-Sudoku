Phase 3.66.1 — Deep Free Play: Bundled Pool + Rolling Cache.

Než cokoliv navrhneš, přečti si z disku:
- `lib/games/runic_sudoku/generator/puzzle_generator.dart`
- `lib/games/runic_sudoku/generator/free_play_guardrails.dart`
- `lib/games/runic_sudoku/generator/level_data.dart`
- `lib/core/save/save_service.dart`
- `lib/core/save/local_save_repository.dart`
- `lib/games/runic_sudoku/runic_sudoku_screen.dart` (jak se aktuálně spouští Free Play)

Kontext: audit ukázal, že Deep on-demand generování s freeplay guardrails má P95 = 2s a P99 = 3s na PC (reálně 6-10s na low-end Android), P95 rejections = 602, a 1 failure z 200 pokusů. Deep nikdy nebude generován on-demand při kliknutí hráče.

---

## Architektura

**Vrstva 1 — Bundled starting pool**
- 75 předgenerovaných Deep puzzle s freeplay guardrails
- Uložené v `assets/freeplay/deep_pool.json`
- Vždy dostupné offline, žádné čekání
- Hráč z tohoto poolu čerpá dokud není rolling cache k dispozici

**Vrstva 2 — Rolling cache**
- 15 Deep puzzle generovaných na pozadí, uložených v `SharedPreferences`
- Doplňuje se automaticky na pozadí (Dart `Isolate`), nikdy ne při aktivním puzzle flow
- Priorita: nejdřív spotřebuj cache, pak bundled pool
- Background generation se zastaví při:
  - spuštění puzzle (kampaň, free play, daily)
  - odchodu do popředí nové obrazovky s aktivní hrou
  - ukončení appky (`AppLifecycleState.paused/detached`)

**Fallback** (pouze pokud je bundled pool i cache vyčerpán — nemělo by nastat při 75 bundled puzzle):
```
Deep Trials are being prepared.
Try another difficulty and return shortly.
```

---

## Puzzle identity a deduplication

Každé Deep Free Play puzzle musí mít stabilní `puzzleId`:
- Pro bundled pool: `deep_fp_000` až `deep_fp_074`
- Pro cache puzzle: deterministický hash z `given_cells` (např. SHA-1 prvních 16 bytes, nebo jednodušší: string join všech hodnot → hash)

Udržuj v `PlayerProfile` (nebo samostatném `FreePLayDeepState`):
- `deepUsedIds: Set<String>` — puzzle která byla již zobrazena hráči
- Při výběru dalšího puzzle: preferuj nepoužité; pokud jsou všechny použité, zamíchej a začni znovu (cyklické opakování je OK, jen ho neoznačuj jako "nový" puzzle)

---

## Generátor skript

Vytvoř `tool/generate_freeplay_deep_pool.dart`:
- Generuje 75 Deep puzzle s freeplay guardrails (`freePlay: true` flag)
- Exportuje do `assets/freeplay/deep_pool.json`
- Každé puzzle dostane `puzzleId: "deep_fp_NNN"`
- Vypiš progress a výslednou statistiku (rejection avg, gen time avg)
- Spusť skript a commitni výsledný JSON

Přidej `assets/freeplay/` do `pubspec.yaml` assets sekce.

---

## Rolling cache implementace

Vytvoř `DeepFreePlayCache` service:

```dart
class DeepFreePlayCache {
  // Maximální velikost cache
  static const int maxCacheSize = 15;
  
  // Získej další puzzle (z cache, pak z bundled pool)
  Future<LevelData> nextPuzzle();
  
  // Spusť background doplňování (pokud cache < maxCacheSize)
  void startRefill();
  
  // Zastav background generování
  void stopRefill();
  
  // Je cache k dispozici?
  bool get hasCache;
}
```

- Cache persistována v `SharedPreferences` jako JSON list (klíč: `deep_freeplay_cache`)
- Background Isolate generuje jedno puzzle najednou, po dokončení uloží do cache a zkontroluje jestli má pokračovat
- `stopRefill()` pošle cancel signal do Isolate
- Cache se nesmí plnit pokud je hráč v aktivní hře — kontroluj přes `AppController` stav nebo jednoduchý bool flag

---

## Integrace do Free Play UI

Uprav `FreeDifficultySelectScreen` a Free Play flow:
- Deep tlačítko: při kliknutí okamžitě vezmi puzzle z `DeepFreePlayCache.nextPuzzle()` (žádné generování, žádné čekání)
- Loading overlay pro Deep: zobraz jen pokud `nextPuzzle()` z nějakého důvodu trvá déle než 200ms (nemělo by nastat — čtení z cache/bundled je okamžité)
- Quick/Normal/Tricky: on-demand generování přes `compute()` beze změny

---

## Životní cyklus cache

`AppController` (nebo `main.dart`) při startu:
1. Inicializuj `DeepFreePlayCache`
2. Načti existující cache z `SharedPreferences`
3. Pokud cache < 5 puzzle: spusť `startRefill()` na pozadí ihned
4. Jinak: odlož `startRefill()` na po prvním puzzle (aby nebrzdil startup)

Při přechodu do puzzle (`level_start` trigger): `stopRefill()`
Při návratu z puzzle (`level_complete`, `app_pause`): `startRefill()` pokud cache < maxCacheSize

---

## Testy

- `DeepFreePlayCache.nextPuzzle()` vrátí puzzle z cache pokud existuje
- `DeepFreePlayCache.nextPuzzle()` fallback na bundled pool pokud cache prázdná
- Fallback hláška pokud jsou obě vrstvy prázdné (testuj s prázdným bundled poolem)
- `deepUsedIds` se aktualizuje po každém zobrazeném puzzle
- Background refill se nezastaví pokud není v aktivní hře (testuj AppLifecycle mockováním)
- Bundled pool JSON je validní (všechna puzzle mají validní solution_grid, given_cells ⊆ solution)

Existující testy musí projít beze změny.

---

## Constraints

- Nikdy nespouštěj Deep generování synchronně na UI thread
- Background Isolate nesmí blokovat UI při aktivní hře
- Bundled pool nesmí být modifikován za běhu — je to read-only asset
- Neměň kampaňový pool ani daily puzzle logiku
- `deepUsedIds` může růst neomezeně (Set<String>, malá data)

## Výstup

1. Architektonický plán
2. Nové/upravené soubory (včetně tool skriptu)
3. Implementace
4. Testy
5. Implementation decisions I made
6. Not implemented / deferred ideas
7. Specification ambiguities

Na konci uveď výsledek `dart run tool/generate_freeplay_deep_pool.dart` pokud sandbox umožňuje spuštění, nebo řekni explicitně že sandbox nemá Dart SDK.
