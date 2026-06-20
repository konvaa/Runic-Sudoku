import 'save_trigger_type.dart';
import 'snapshot.dart';

/// App-wide save interface. Implementations persist *complete* snapshots.
///
/// Reads return raw JSON maps rather than typed snapshots because App Core does
/// not know about concrete game snapshot types; the calling game module rebuilds
/// its own type via its `fromJson` factory.
abstract class SaveService {
  /// Persists [snapshot] completely. [trigger] explains why and may influence
  /// flush behavior, but the saved payload is always the full snapshot.
  Future<void> save(Snapshot snapshot, SaveTriggerType trigger);

  /// Returns the raw JSON map stored at [saveKey], or null if none exists.
  Future<Map<String, dynamic>?> load(String saveKey);

  /// True if a snapshot exists at [saveKey].
  Future<bool> hasSave(String saveKey);

  /// Removes the snapshot at [saveKey] (e.g. on level completion or reset).
  Future<void> delete(String saveKey);
}
