Malá kosmetická oprava v level select obrazovce. Žádné změny logiky, progression, ani jiných obrazovek.

Přečti si z disku:
- `lib/app/level_select_screen.dart`

Problém: levely s `estimated_solve_time` pod 60 sekund zobrazují "~0 min" — to vypadá divně a neprofesionálně.

Oprava: při formátování `estimated_solve_time` pro zobrazení v level select použij minimum 1 minutu:

```dart
// Místo:
'~${(estimatedSolveTime / 60).round()} min'

// Použij:
'~${max(1, (estimatedSolveTime / 60).round())} min'
```

Nebo alternativně pro hodnoty pod 60 sekund zobraz "< 1 min" místo "~0 min" — zvol co vypadá lépe v kontextu ostatních levelů (kde většina ukazuje "~1 min").

Po opravě:
- Spusť `flutter test` — existující testy musí projít
- Ověř vizuálně že žádný level neukazuje "~0 min"
- Žádné jiné změny
