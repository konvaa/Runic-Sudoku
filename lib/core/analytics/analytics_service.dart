/// A single analytics event payload. Stable Phase 1 contract.
///
/// `name` is a snake_case event key; `params` carries primitive values only
/// (String / num / bool / null) so any real backend (Firebase, Amplitude, etc.)
/// can map it through an adapter without re-modelling.
class AnalyticsEvent {
  final String name;
  final Map<String, Object?> params;
  final DateTime timestamp;

  AnalyticsEvent(
    this.name, {
    Map<String, Object?>? params,
    DateTime? timestamp,
  })  : params = params ?? const {},
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'params': params,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'AnalyticsEvent($name, $params)';
}

/// App-wide analytics interface.
abstract class AnalyticsService {
  /// Records an event. Must never throw to the caller — analytics is best-effort.
  Future<void> logEvent(AnalyticsEvent event);

  /// Convenience wrapper for the common name+params case.
  Future<void> log(String name, [Map<String, Object?>? params]) =>
      logEvent(AnalyticsEvent(name, params: params));
}
