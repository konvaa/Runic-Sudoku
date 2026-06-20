import 'purchase_service.dart';

/// No-op purchases service returning a valid mock success so calling code can be
/// wired to real billing later without API changes.
///
/// It keeps a single in-memory "remove ads" entitlement flag so the rest of the
/// app can react to ownership state realistically during Phase 1.
class NoopPurchaseService implements PurchaseService {
  bool _removeAdsOwned;
  final Duration latency;

  NoopPurchaseService({
    bool removeAdsOwned = false,
    this.latency = const Duration(milliseconds: 300),
  }) : _removeAdsOwned = removeAdsOwned;

  @override
  Future<PurchaseResult> purchaseRemoveAds() async {
    await Future<void>.delayed(latency);
    if (_removeAdsOwned) {
      return const PurchaseResult.alreadyOwned(ProductIds.removeAds);
    }
    _removeAdsOwned = true;
    return const PurchaseResult.success(ProductIds.removeAds);
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    await Future<void>.delayed(latency);
    return [
      if (_removeAdsOwned) const PurchaseResult.alreadyOwned(ProductIds.removeAds),
    ];
  }

  @override
  Future<bool> isRemoveAdsOwned() async => _removeAdsOwned;
}
