Po opravě bugů selhal jeden test:

```
test/persistence_test.dart: profile persists across a simulated restart [E]
Expected: true
  Actual: <false>
completion persisted
```

Než cokoliv opravíš, přečti si z disku:
- `test/persistence_test.dart` (celý soubor — zjisti, co přesně test dělá a co testuje)
- `lib/games/runic_sudoku/runic_sudoku_screen.dart` (jak se teď volá recordCompletion s isDaily parametrem)
- `lib/core/profile/app_controller.dart` (jak onLevelCompleted zachází s isDaily)

Diagnostikuj nejdřív:
- Testuje "completion persisted" campaign level nebo daily level?
- Pokud campaign level: proč se po opravě Bug 1 přestalo zapisovat do `completedLevelIds` i pro campaign completion (to by byl over-eager fix)?
- Pokud daily level: test byl napsaný s předpokladem starého chování (daily POČÍTÁ do kampane), a teď je záměrně jiné — pak je správné opravit test, ne produkční kód.

Oprav příčinu:
- Pokud je chyba v produkčním kódu (campaign completion se taky nezapisuje) → oprav `recordCompletion`/`onLevelCompleted`, aby campaign completion pořád zapisovalo do `completedLevelIds`.
- Pokud je chyba v testu (testuje daily level a starý stav byl nesprávný předpoklad) → uprav test tak, aby testoval campaign completion místo daily completion, nebo explicitně testoval oba scénáře zvlášť (campaign completion = zapisuje, daily completion = nezapisuje).

Neopravuj symptom (např. `expect(false, false)`) — oprav test tak, aby ověřoval správné nové chování.

Po opravě: spusť `flutter test` pokud máš sandbox; pokud ne, řekni to explicitně. Cílem je 70+ testů passing, 0 failing.
