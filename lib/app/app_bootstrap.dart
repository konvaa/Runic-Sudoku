import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads/ads_service.dart';
import '../core/ads/noop_ads_service.dart';

/// Boots the app in two phases so the UMP consent form is never presented
/// over a blank Activity.
///
/// Phase 1: [runApp] mounts this widget immediately and a lightweight dark
/// boot frame is painted — no consent, network, or ads dependency.
/// Phase 2: scheduled via [WidgetsBinding.addPostFrameCallback], i.e. only
/// after the first frame is actually on screen, the UMP consent flow runs,
/// exactly one [AdsService] is constructed from its outcome, and the real app
/// is swapped in.
///
/// Rationale (fix/ump-consent-gating, commit 3): the consent form triggered
/// before `runApp()` rendered invisibly over the not-yet-drawn Activity on
/// some devices (confirmed on Xiaomi 13T Pro, Android 16/HyperOS), while the
/// same form triggered after the app was fully rendered displayed correctly.
///
/// Fail-closed guarantees: if the consent flow throws, or has not resolved
/// within [consentTimeout], the app proceeds with [NoopAdsService] instead of
/// leaving the user stuck on the boot screen. A late consent choice is still
/// persisted by UMP and is honoured on the next launch.
class AppBootstrap extends StatefulWidget {
  /// Default for [consentTimeout] — the single place to retune it.
  ///
  /// Generous on purpose: a careful reader may spend well over a minute in
  /// the consent form (purposes, vendor list, "manage options") before
  /// choosing. This bound exists to catch a genuinely stuck consent flow,
  /// not to race the user.
  static const Duration defaultConsentTimeout = Duration(seconds: 90);

  /// Runs the consent flow; resolves true when ads may be requested
  /// (production: `UmpConsent.gatherConsentThenInitialize`).
  final Future<bool> Function() gatherConsent;

  /// Builds the session's ads service from the consent outcome. Exceptions
  /// fall back to [NoopAdsService].
  final AdsService Function(bool adsAllowed) buildAdsService;

  /// Builds the real app once the ads service is decided.
  final Widget Function(AdsService ads) buildApp;

  /// Upper bound on the whole consent flow (info update + form + choice).
  /// On expiry the session proceeds with [NoopAdsService] (fail closed).
  final Duration consentTimeout;

  const AppBootstrap({
    super.key,
    required this.gatherConsent,
    required this.buildAdsService,
    required this.buildApp,
    this.consentTimeout = defaultConsentTimeout,
  });

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Widget? _app;

  @override
  void initState() {
    super.initState();
    // Post-frame on purpose: the consent dialog must only ever appear over
    // painted content (see class docs).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    var adsAllowed = false;
    try {
      adsAllowed = await widget
          .gatherConsent()
          .timeout(widget.consentTimeout, onTimeout: () => false);
    } catch (_) {
      adsAllowed = false; // fail closed: no consent signal → no ads
    }
    if (!mounted) return;
    AdsService ads;
    try {
      ads = widget.buildAdsService(adsAllowed);
    } catch (_) {
      ads = const NoopAdsService(); // ads issues never block the game
    }
    setState(() => _app = widget.buildApp(ads));
  }

  @override
  Widget build(BuildContext context) {
    return _app ?? const _BootScreen();
  }
}

/// Minimal dependency-free boot frame matching the app's dark look (same
/// background as the system navigation bar colour set in `main()`).
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white30),
        ),
      ),
    );
  }
}
