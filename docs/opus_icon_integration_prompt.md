Malý, uzavřený úkol — zapojit hotovou app ikonu do projektu, nesouvisí s žádnou herní logikou.

Mám hotový obrázek ikony (`icon.png`, 1254×1254px, tmavý kámen s zlatou 6×6 mřížkou a rune symboly) — vložím ho do projektu na cestu, kterou určíš (typicky `assets/icon/icon.png` nebo podobně, podle konvence balíčku, který použiješ).

Úkol:

1. **Přidej `flutter_launcher_icons` jako dev dependency** (oficiální, široce používaný balíček pro generování platform-specific ikon ze zdrojového obrázku — zdůvodni stručně v Implementation decisions, že je to standardní volba, ne něco k vymýšlení od nuly).

2. **Nakonfiguruj ho v `pubspec.yaml`** pro:
   - Android: standardní ikona + adaptive icon (foreground/background) — pokud zdrojový obrázek nemá oddělené foreground/background vrstvy (je to jeden plochý PNG), použij ho jako základ pro obojí s rozumným paddingem pro adaptive icon safe zone (Android adaptive icony ořezávají okraje podle launcheru, takže potřebuješ menší padding, aby se nic důležitého neuřízlo).
   - iOS: standardní app icon set (i když iOS build teď není primární cíl, konfigurace ať je připravená).
   - Windows desktop (protože to je platforma, na které vývojář testuje přes `flutter run -d windows`).

3. **Spusť/připrav příkaz pro generování** (`flutter pub run flutter_launcher_icons` nebo `dart run flutter_launcher_icons`) — pokud sandbox nemá Dart SDK (jako v předchozích fázích), řekni to explicitně a napiš přesný příkaz, který mám spustit já.

4. **Ověř, že žádný existující soubor se needucetně nepřepíše** — pokud `flutter_launcher_icons` generuje do standardních platform složek (`android/app/src/main/res/...`, `windows/runner/resources/...`), to je očekávané a v pořádku (jsou to generované assety, ne ruční kód), ale pokud by cokoliv jiného mělo být přepsáno, uveď to.

Co NEDĚLAT:
- Neuprav obrázek samotný (žádné cropování/úpravy bez zeptání) — pokud je potřeba nějaká transformace (např. odstranění průhlednosti, padding pro adaptive icon), popiš co a proč, ale neměň umělecký obsah.
- Nezasahuj do žádné herní logiky, levelů, ani jiné části kódu.
- Nepřidávej žádné další dependencies mimo `flutter_launcher_icons`.

Výstup: krátké shrnutí konfigurace + přesný příkaz/postup k dokončení (pokud něco musím spustit já kvůli chybějícímu Dart SDK v sandboxu).
