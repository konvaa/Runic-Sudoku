// Unit tests for the UMP consent gate (branch fix/ump-consent-gating).
//
// The compliance-relevant property under test: the Mobile Ads SDK is
// initialised ONLY when ConsentInformation.canRequestAds() reports true, and
// the gate fails closed (no init, no throw) when the consent state is
// unavailable.
//
// Seams used (only one small hook added to production code):
// - `ConsentInformation.instance` is a public MUTABLE static in
//   google_mobile_ads 5.3.1 (lib/src/ump/consent_information.dart:71), so the
//   consent state is substituted with a scriptable fake.
// - `UmpConsent.initializeMobileAds` (@visibleForTesting) stands in for
//   MobileAds.instance.initialize(), whose singleton is not substitutable.
// - The UMP method channel is mocked by name for the one argument-less call
//   the success path makes (ConsentForm.loadAndShowConsentFormIfRequired), so
//   the REAL ConsentForm Dart code runs in the success-path test.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:runic_sudoku/core/ads/ump_consent.dart';

/// Name of the plugin's UMP platform channel (google_mobile_ads 5.3.1,
/// lib/src/ump/user_messaging_channel.dart:26).
const MethodChannel _umpChannel =
    MethodChannel('plugins.flutter.io/google_mobile_ads/ump');

/// Scriptable stand-in for the platform consent state.
class _FakeConsentInformation implements ConsentInformation {
  _FakeConsentInformation({
    required this.canRequestAdsResult,
    this.infoUpdateSucceeds = true,
    this.privacyOptionsStatus = PrivacyOptionsRequirementStatus.unknown,
    this.throwOnPrivacyOptionsStatus = false,
    this.onEvent,
  });

  /// Result of [canRequestAds]; null simulates "state unavailable" (throws).
  final bool? canRequestAdsResult;

  /// Whether [requestConsentInfoUpdate] reports success or failure.
  final bool infoUpdateSucceeds;

  final PrivacyOptionsRequirementStatus privacyOptionsStatus;
  final bool throwOnPrivacyOptionsStatus;

  /// Records the order of consent-flow events for assertions.
  final void Function(String event)? onEvent;

  @override
  void requestConsentInfoUpdate(
      ConsentRequestParameters params,
      OnConsentInfoUpdateSuccessListener successListener,
      OnConsentInfoUpdateFailureListener failureListener) {
    onEvent?.call('requestConsentInfoUpdate');
    if (infoUpdateSucceeds) {
      successListener();
    } else {
      failureListener(FormError(errorCode: 1, message: 'update failed'));
    }
  }

  @override
  Future<bool> canRequestAds() async {
    onEvent?.call('canRequestAds');
    final result = canRequestAdsResult;
    if (result == null) throw StateError('consent state unavailable');
    return result;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
      getPrivacyOptionsRequirementStatus() async {
    if (throwOnPrivacyOptionsStatus) throw StateError('unavailable');
    return privacyOptionsStatus;
  }

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.unknown;

  @override
  Future<void> reset() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConsentInformation realConsentInformation;
  late Future<void> Function() realInitialize;
  late int initCalls;
  late List<String> events;

  setUp(() {
    realConsentInformation = ConsentInformation.instance;
    realInitialize = UmpConsent.initializeMobileAds;
    initCalls = 0;
    events = <String>[];
    UmpConsent.initializeMobileAds = () async {
      initCalls++;
      events.add('initialize');
    };
    // The consent-form call is argument-less, so a name-keyed mock using the
    // standard codec is wire-compatible with the plugin's channel; replying
    // null means "form dismissed (or not required), no error".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_umpChannel, (call) async {
      events.add('channel:${call.method}');
      return null;
    });
  });

  tearDown(() {
    ConsentInformation.instance = realConsentInformation;
    UmpConsent.initializeMobileAds = realInitialize;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_umpChannel, null);
  });

  test('consent denies ad requests -> SDK is never initialised', () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: false, onEvent: events.add);

    final allowed = await UmpConsent.gatherConsentThenInitialize();

    expect(allowed, isFalse);
    expect(initCalls, 0, reason: 'no init call may happen without consent');
  });

  test('consent allows ad requests -> SDK initialised once, after the flow',
      () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true, onEvent: events.add);

    final allowed = await UmpConsent.gatherConsentThenInitialize();

    expect(allowed, isTrue);
    expect(initCalls, 1);
    expect(events, <String>[
      'requestConsentInfoUpdate',
      'channel:UserMessagingPlatform#loadAndShowConsentFormIfRequired',
      'canRequestAds',
      'initialize',
    ]);
  });

  test('info update fails but stored consent allows ads -> still initialises',
      () async {
    // Offline relaunch after consent was given in an earlier session.
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true,
        infoUpdateSucceeds: false,
        onEvent: events.add);

    expect(await UmpConsent.gatherConsentThenInitialize(), isTrue);
    expect(initCalls, 1);
  });

  test('info update fails and no stored consent -> no init', () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: false,
        infoUpdateSucceeds: false,
        onEvent: events.add);

    expect(await UmpConsent.gatherConsentThenInitialize(), isFalse);
    expect(initCalls, 0);
  });

  test('consent state unavailable -> fails closed without init or throw',
      () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: null, onEvent: events.add);

    expect(await UmpConsent.gatherConsentThenInitialize(), isFalse);
    expect(initCalls, 0);
  });

  test('SDK init failure reports ads as not allowed', () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true, onEvent: events.add);
    UmpConsent.initializeMobileAds = () async {
      initCalls++;
      throw StateError('init failed');
    };

    expect(await UmpConsent.gatherConsentThenInitialize(), isFalse);
    expect(initCalls, 1);
  });

  test('privacy options entry point required only when UMP says so', () async {
    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true,
        privacyOptionsStatus: PrivacyOptionsRequirementStatus.required);
    expect(await UmpConsent.isPrivacyOptionsRequired(), isTrue);

    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true,
        privacyOptionsStatus: PrivacyOptionsRequirementStatus.notRequired);
    expect(await UmpConsent.isPrivacyOptionsRequired(), isFalse);

    ConsentInformation.instance = _FakeConsentInformation(
        canRequestAdsResult: true, throwOnPrivacyOptionsStatus: true);
    expect(await UmpConsent.isPrivacyOptionsRequired(), isFalse);
  });
}
