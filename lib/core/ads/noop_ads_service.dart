import 'ads_service.dart';

/// No-op ads service returning realistic, valid results so calling code can be
/// wired to real ads later without API changes.
///
/// Rewarded ads always "complete" (reward granted) and interstitials are always
/// "shown". A small artificial delay mimics real ad presentation so UI flows
/// (spinners, pause/resume) behave the same as in production.
class NoopAdsService implements AdsService {
  final Duration latency;

  const NoopAdsService({this.latency = const Duration(milliseconds: 300)});

  @override
  Future<AdResult> showRewardedAd({String? placement}) async {
    await Future<void>.delayed(latency);
    return AdResult.completed(placement: placement);
  }

  @override
  Future<AdResult> showInterstitial({String? placement}) async {
    await Future<void>.delayed(latency);
    return AdResult.shown(placement: placement);
  }

  @override
  Future<bool> isAdAvailable({String? placement}) async => true;
}
