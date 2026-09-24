# Runic Sudoku

Fantasy logická hra pro Android na principu sudoku: mřížky 6×6 s runovými
symboly místo čísel, kampaň ve čtyřech kapitolách obtížnosti (Quick /
Normal / Tricky / Deep) a režim Free Play.
První titul vydaný pod indie značkou Jantrel.

**[Stáhnout na Google Play](https://play.google.com/store/apps/details?id=com.konvicny.runicsudoku)**

<!-- Screenshot: doplnit obrázek a odkomentovat.
![Runic Sudoku – herní obrazovka](docs/screenshots/gameplay.png)
-->

## Stack

- **Flutter / Dart**, aktuálně cíleno na Android
- **Firebase Crashlytics**: hlášení pádů v produkci
- **Google Mobile Ads + UMP**: reklamy s GDPR consent flow (trhy EU)
- **in_app_purchase**: nákup odstranění reklam
- **shared_preferences**: lokální uložení postupu a profilu hráče

## Co je potřeba k buildu

Tři soubory v repozitáři nejsou. Jsou vázané na můj Firebase projekt
a podpisový klíč, pro vlastní build si je vytvoříš sám:

| Soubor | Jak ho získat |
|---|---|
| `android/app/google-services.json` | Firebase Console → Project settings → Android app → stáhnout |
| `lib/firebase_options.dart` | `dart pub global activate flutterfire_cli` a pak `flutterfire configure` |
| `android/key.properties` | zkopírovat `android/key.properties.example` a vyplnit (keystore vytvoříš přes `keytool`) |

`android/key.properties` je v současné konfiguraci potřeba i pro debug build,
protože `android/app/build.gradle.kts` čte podpisové hodnoty bez fallbacku.

## Spuštění

```sh
flutter pub get
flutter run                     # připojené zařízení nebo emulátor
flutter test
flutter build appbundle         # release pro Google Play
```

Vyžaduje Flutter 3.27+ (Dart 3.4+) a Android API 23+.
