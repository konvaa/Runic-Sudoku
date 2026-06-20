# App icon source

Place the source icon here as **`icon.png`** (the provided 1254×1254 stone-tablet
artwork). This single flat PNG is the source for all platform launcher icons.

It is consumed at **build time** by `flutter_launcher_icons` (configured in
`pubspec.yaml`) and is NOT a runtime Flutter asset, so it is intentionally not
listed under `flutter: assets:`.

To (re)generate the platform icons after adding/updating `icon.png`:

```
flutter pub get
dart run flutter_launcher_icons
```

This writes generated icons into the platform folders (Android `res/`, iOS
`Assets.xcassets`, Windows `runner/resources`). Those are generated assets, not
hand-written code.
