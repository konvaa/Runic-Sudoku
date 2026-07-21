import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google User Messaging Platform (UMP) GDPR consent flow (Phase 4).
///
/// MUST complete BEFORE AdMob is initialized. UMP decides on its own whether a
/// form is needed (EU/EEA users incl. CZ), so this is safe to call on every
/// launch — it shows a form only when required.
///
/// The Mobile Ads SDK is initialized ONLY if UMP then reports that ad requests
/// are allowed ([ConsentInformation.canRequestAds]). When they are not, the
/// SDK stays uninitialized, no ad may be requested this session, and the
/// caller must fall back to a no-ads mode.
class UmpConsent {
  const UmpConsent._();

  /// Initialises the Mobile Ads SDK. Test seam ONLY — production code must
  /// never reassign this. It exists so unit tests can verify the consent gate
  /// (no SDK init unless `canRequestAds() == true`) without the platform SDK;
  /// see `test/ump_consent_gating_test.dart`. The app's single real
  /// `MobileAds.instance.initialize()` call site lives in this default value.
  @visibleForTesting
  static Future<void> Function() initializeMobileAds =
      () => MobileAds.instance.initialize();

  /// Runs the consent flow, then initialises the Mobile Ads SDK — but only
  /// when [ConsentInformation.canRequestAds] allows ad requests.
  ///
  /// Returns true when the SDK was initialised (ads may be loaded), false when
  /// ads must stay disabled for this session. Never throws — fails CLOSED:
  /// consent-flow errors are swallowed and the outcome is decided solely by
  /// `canRequestAds()` (which may still be true from consent stored in a
  /// previous session, e.g. an offline relaunch after consent was given); if
  /// even the consent state cannot be determined, or SDK init fails, this
  /// reports false so the caller wires the no-ads path.
  static Future<bool> gatherConsentThenInitialize() async {
    try {
      await _gatherConsent();
    } catch (_) {
      // Ignore: `canRequestAds()` below still decides the outcome.
    }
    try {
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!canRequestAds) return false;
      await initializeMobileAds();
      return true;
    } catch (_) {
      // Fail closed: unknown consent state (or failed SDK init) → no ads.
      return false;
    }
  }

  /// Whether the app must offer a privacy-options entry point (UMP requires
  /// one for EEA users so they can revisit their consent choice).
  ///
  /// Returns false on any error (e.g. platforms/tests without the plugin).
  static Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Shows the UMP privacy-options form so the user can change their consent.
  ///
  /// Resolves after the form is dismissed (verified against
  /// google_mobile_ads 5.3.1: the returned Future completes only after the
  /// native dismissed callback fired). A withdrawn consent stops new ad
  /// requests via the `canRequestAds()` checks before every load; the ads
  /// service wiring itself is refreshed on the next app launch.
  static Future<void> showPrivacyOptionsForm() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        // Form errors are non-fatal — the current consent state simply stays.
      });
    } catch (_) {
      // Never throws: an unavailable form leaves the consent state unchanged.
    }
  }

  static Future<void> _gatherConsent() {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          // Loads + shows the form only if UMP says it is required. In
          // google_mobile_ads 5.3.1 this Future resolves only after the form
          // was dismissed (or immediately when no form is required).
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            // Form error is non-fatal — just finish the flow.
          });
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        // requestConsentInfoUpdate failed — finish the flow; consent stored in
        // a previous session (if any) still decides via canRequestAds().
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }
}
