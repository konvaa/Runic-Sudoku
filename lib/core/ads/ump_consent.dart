import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google User Messaging Platform (UMP) GDPR consent flow (Phase 4).
///
/// MUST complete BEFORE AdMob is initialized. UMP decides on its own whether a
/// form is needed (EU/EEA users incl. CZ), so this is safe to call on every
/// launch — it shows a form only when required. On any error it falls through so
/// the app still works (ads then run in a non-personalised / safe mode).
class UmpConsent {
  const UmpConsent._();

  /// Runs the consent flow, then initialises the Mobile Ads SDK. Always resolves
  /// (never throws): consent failures fall back to initialising AdMob anyway.
  static Future<void> gatherConsentThenInitialize() async {
    try {
      await _gatherConsent();
    } catch (_) {
      // Ignore: proceed to AdMob init regardless (safe fallback).
    }
    await MobileAds.instance.initialize();
  }

  static Future<void> _gatherConsent() {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          // Loads + shows the form only if UMP says it is required.
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            // Form error is non-fatal — just finish the flow.
          });
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        // requestConsentInfoUpdate failed — proceed without consent.
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }
}
