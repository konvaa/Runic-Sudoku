Runic Sudoku

Fantasy logická hra pro Android postavená na principu sudoku – 6×6 mřížky s runovými symboly místo čísel, kampaň s narůstající obtížností a volitelný Expert mód. Vydáno pod značkou Jantrel na Google Play pro trhy CZ / SK / AT / DE / PL.

Verze: 0.1.1+4 · Stack: Flutter / Dart

Ke stažení

Google Play: https://play.google.com/store/apps/details?id=com.konvicny.runicsudoku

O aplikaci

Runic Sudoku bere známý sudoku princip a staví ho do vlastního fantasy světa – runy, magické motivy, tematické kapitoly namísto čistě číselné mřížky. Kampaň je rozdělená do kapitol s pevně danou obtížností (Quick / Normal / Tricky / Deep), doplněná o volitelný Free Play a Expert (12×12) mód pro hráče, kteří chtějí víc než kampaň nabízí.

Technický stack
Flutter / Dart – multiplatformní engine (aktuálně cíleno na Android)
Firebase Crashlytics – crash reporting v produkci
Google Mobile Ads SDK + UMP – monetizace reklamou s plným GDPR/UMP consent flow (EU trhy)
in_app_purchase – nákup v aplikaci (remove ads)
shared_preferences – lokální ukládání postupu a profilu hráče
Architektura

Obsahová vrstva (kapitoly, obtížnosti, levely) je oddělená od herní logiky přes explicitní datový kontrakt (ChapterDefinition / TierDefinition / CampaignRegistry), díky kterému lze bezpečně přidávat nový obsah bez rizika, že se rozbije existující kampaň. Kontrakt je pokrytý diferenciálním testem porovnávajícím stovky herních stavů proti referenční implementaci.

Levely mají stabilní explicitní ID napříč kapitolami, což umožňuje bezpečné verzování obsahu i zpětnou kompatibilitu uložených postupů hráčů.

Stav vývoje
✅ Kapitola 1 – hotová a live
🚧 Kapitola 2 – datový model a obsah ve vývoji
📋 Plán: Free Play (9×9), rozšíření Expert módu
Jantrel

Runic Sudoku je první titul vydaný pod indie herní značkou Jantrel. Web: jantrel-web.web.app
