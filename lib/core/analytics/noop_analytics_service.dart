import 'dart:developer' as developer;

import 'analytics_service.dart';

/// No-op analytics. Completes successfully and (in debug) logs to the dev
/// console so events are observable while no real backend is wired up.
///
/// It honors the full [AnalyticsService] contract so swapping in a real backend
/// later requires no caller changes.
class NoopAnalyticsService implements AnalyticsService {
  final bool echoToConsole;

  const NoopAnalyticsService({this.echoToConsole = true});

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    if (echoToConsole) {
      developer.log(event.toString(), name: 'analytics');
    }
  }

  @override
  Future<void> log(String name, [Map<String, Object?>? params]) =>
      logEvent(AnalyticsEvent(name, params: params));
}
