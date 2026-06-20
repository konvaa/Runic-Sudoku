import 'dart:convert';

import 'save_service.dart';
import 'save_trigger_type.dart';
import 'snapshot.dart';

/// Minimal string key/value persistence abstraction.
///
/// Phase 1 ships only [InMemorySaveStore] (zero dependencies, fully testable).
/// Phase 2 can drop in a `SharedPreferencesSaveStore` or a file-backed store
/// without touching [LocalSaveRepository] or any caller. See PHASE1_NOTES.md.
abstract class SaveStore {
  Future<void> put(String key, String value);
  Future<String?> get(String key);
  Future<void> remove(String key);
  Future<bool> containsKey(String key);
}

/// Volatile in-memory store. Survives within a running app session only.
class InMemorySaveStore implements SaveStore {
  final Map<String, String> _data = {};

  @override
  Future<void> put(String key, String value) async => _data[key] = value;

  @override
  Future<String?> get(String key) async => _data[key];

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
}

/// [SaveService] that stores complete snapshots as JSON strings in a [SaveStore].
class LocalSaveRepository implements SaveService {
  final SaveStore store;

  LocalSaveRepository({SaveStore? store})
      : store = store ?? InMemorySaveStore();

  @override
  Future<void> save(Snapshot snapshot, SaveTriggerType trigger) async {
    final payload = jsonEncode(snapshot.toJson());
    await store.put(snapshot.saveKey, payload);
    // `trigger` is intentionally not persisted in the slot; Phase 2 may forward
    // it to analytics or use it to decide on immediate durable flushing.
  }

  @override
  Future<Map<String, dynamic>?> load(String saveKey) async {
    final raw = await store.get(saveKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<bool> hasSave(String saveKey) => store.containsKey(saveKey);

  @override
  Future<void> delete(String saveKey) => store.remove(saveKey);
}
