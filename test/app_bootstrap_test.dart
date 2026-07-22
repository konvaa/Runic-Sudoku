// Widget tests for AppBootstrap (fix/ump-consent-gating, commit 3).
//
// Properties under test: a boot frame is painted BEFORE the consent flow
// runs (the whole point of the widget — the UMP form must appear over
// rendered content), and the widget fails closed (adsAllowed == false /
// NoopAdsService) when the consent flow times out, throws, or the ads-service
// builder itself fails — the user is never left stuck on the boot screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runic_sudoku/app/app_bootstrap.dart';
import 'package:runic_sudoku/core/ads/ads_service.dart';
import 'package:runic_sudoku/core/ads/noop_ads_service.dart';

const Key _appKey = Key('real-app');

void main() {
  testWidgets('paints boot screen first, then app once consent resolves',
      (tester) async {
    bool? receivedAllowed;
    await tester.pumpWidget(AppBootstrap(
      gatherConsent: () async => true,
      buildAdsService: (allowed) {
        receivedAllowed = allowed;
        return const NoopAdsService();
      },
      buildApp: (ads) => const SizedBox(key: _appKey),
    ));

    // First frame: boot screen only — consent had no chance to run before it.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(_appKey), findsNothing);

    await tester.pump();
    await tester.pump();

    expect(receivedAllowed, isTrue);
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('fails closed when the consent flow never resolves (timeout)',
      (tester) async {
    // Pin the shipped default so a retune is a conscious, reviewed change.
    expect(AppBootstrap.defaultConsentTimeout, const Duration(seconds: 90));

    bool? receivedAllowed;
    final never = Completer<bool>();
    await tester.pumpWidget(AppBootstrap(
      // No consentTimeout override: this test exercises the real default.
      gatherConsent: () => never.future,
      buildAdsService: (allowed) {
        receivedAllowed = allowed;
        return const NoopAdsService();
      },
      buildApp: (ads) => const SizedBox(key: _appKey),
    ));

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Just before the default timeout: still on the boot screen. The widget
    // test clock is fake (pump advances it instantly) — no real waiting.
    await tester.pump(
        AppBootstrap.defaultConsentTimeout - const Duration(seconds: 1));
    expect(find.byKey(_appKey), findsNothing);

    // Past the timeout: proceeds with ads disallowed.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(receivedAllowed, isFalse);
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('fails closed when the consent flow throws', (tester) async {
    bool? receivedAllowed;
    await tester.pumpWidget(AppBootstrap(
      gatherConsent: () async => throw StateError('consent unavailable'),
      buildAdsService: (allowed) {
        receivedAllowed = allowed;
        return const NoopAdsService();
      },
      buildApp: (ads) => const SizedBox(key: _appKey),
    ));

    await tester.pump();
    await tester.pump();

    expect(receivedAllowed, isFalse);
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('falls back to NoopAdsService when the ads builder throws',
      (tester) async {
    AdsService? received;
    await tester.pumpWidget(AppBootstrap(
      gatherConsent: () async => true,
      buildAdsService: (_) => throw StateError('ads unavailable'),
      buildApp: (ads) {
        received = ads;
        return const SizedBox(key: _appKey);
      },
    ));

    await tester.pump();
    await tester.pump();

    expect(received, isA<NoopAdsService>());
    expect(find.byKey(_appKey), findsOneWidget);
  });
}
