import 'package:shared_preferences/shared_preferences.dart';

import 'local_save_repository.dart' show SaveStore;

/// Durable [SaveStore] backed by `shared_preferences` — the production store, so
/// `PlayerProfile` (remove-ads, streak, completed levels) and per-level snapshots
/// survive an app restart.
///
/// It implements the exact Phase 1 [SaveStore] interface and reuses the same
/// keys the repository already passes (`app/profile`, `runic_sudoku/<level_id>`,
/// …) — only the backend changed. Snapshots are already JSON strings, so values
/// are stored verbatim via `setString`/`getString`. Local only; no cloud sync,
/// no schema migration.
class SharedPreferencesSaveStore implements SaveStore {
  final SharedPreferences _prefs;

  SharedPreferencesSaveStore(this._prefs);

  /// Obtains the platform [SharedPreferences] instance. Requires the Flutter
  /// binding to be initialized first (done in `main`).
  static Future<SharedPreferencesSaveStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesSaveStore(prefs);
  }

  @override
  Future<void> put(String key, String value) => _prefs.setString(key, value);

  @override
  Future<String?> get(String key) async => _prefs.getString(key);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<bool> containsKey(String key) async => _prefs.containsKey(key);
}
