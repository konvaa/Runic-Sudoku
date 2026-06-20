Malý vizuální task — sjednotit main menu s tmavou fantasy estetikou hry. Žádné změny gameplay logiky, progression, ani monetizace.

Než cokoliv upravíš, přečti si z disku:
- `lib/app/main_menu_screen.dart`
- `lib/games/runic_sudoku/chapter_theme.dart` (ChapterBackground widget + ChapterBackgrounds mapping)
- `assets/backgrounds/` (jaké soubory tam reálně jsou)

Problém: main menu teď používá výchozí Flutter Material téma (béžové/světlé pozadí), zatímco celá hra má tmavou fantasy estetiku (tmavý kámen, zlaté runy, per-chapter pozadí). Vizuální nesoulad je viditelný ihned při spuštění.

Požadované změny:

1. **Pozadí main menu**: použij existující `ChapterBackground` widget (nebo stejný pattern — Image.asset + dark overlay) s `assets/backgrounds/default_rune_bg.png` jako pozadím. Overlay opacity kolem 0.55. Pokud `default_rune_bg.png` neexistuje nebo je nevhodný, použij `quick_runes_bg.png` jako fallback (Stone Hall je vizuálně dobrá "vstupní brána" do hry).

2. **Barvy textu a tlačítek**: přizpůsob tmavému pozadí:
   - Název "Runic Sudoku" a rune logo: světlý text (bílá nebo zlatá/amber), ne tmavý
   - Tlačítko "Daily Puzzle": tmavé/zlaté styling místo současného světle béžového
   - Tlačítko "Campaign": stejný styl jako Daily Puzzle
   - Tlačítko "Settings": outline styl s světlou barvou místo světlého fill
   - Streak text ("🔥 1 day streak"): bílý nebo amber text

3. **Zachovej vše funkční**: žádné změny v navigaci, logice, streak zobrazení, ani v tom, která tlačítka na co vedou.

4. **Konzistence s ostatními obrazovkami**: level select a puzzle screen mají tmavé pozadí přes ChapterBackground — main menu má vypadat jako součást stejné hry, ne jako jiná appka.

Constraints:
- Neměň žádnou herní logiku
- Neměň progression systém
- Neměň navigační strukturu
- Nepřidávej animace
- Nepřidávej nové assety (použij co existuje)
- Drž se existujícího ChapterBackground patternu pro konzistenci

Po dokončení:
- Spusť `flutter test` (existující testy nesmí selhat — změny jsou čistě vizuální)
- Uveď v Implementation decisions: jaký asset jsi použil jako pozadí a proč, jak jsi řešil barvy tlačítek (custom Theme nebo přímé Color hodnoty)
- Pokud narazíš na to, že AppTheme/ThemeData globálně ovlivňuje barvy tlačítek nečekaně, zapiš to do Specification ambiguities
