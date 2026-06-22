import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import 'purchase_service.dart';

/// Google Play Billing implementation of [PurchaseService] (Phase 4).
///
/// Robust by design:
/// - If the store is unavailable, or the `remove_ads` product is not yet created
///   in Play Console (identity verification pending), it degrades gracefully —
///   `queryProductDetails` returning nothing is NOT an error; purchase attempts
///   return [PurchaseStatus.notAvailable] instead of crashing.
/// - `restored` purchases are treated exactly like `purchased`, so Remove Ads
///   survives reinstalls / device changes (Google remembers account purchases).
class PlayBillingService implements PurchaseService {
  final iap.InAppPurchase _iap;

  StreamSubscription<List<iap.PurchaseDetails>>? _sub;
  final StreamController<bool> _entitlement = StreamController<bool>.broadcast();
  Completer<PurchaseResult>? _pending;

  bool _available = false;
  bool _removeAdsOwned = false;
  iap.ProductDetails? _removeAdsProduct;

  PlayBillingService({iap.InAppPurchase? instance})
      : _iap = instance ?? iap.InAppPurchase.instance;

  /// Connects to the store, loads the product, and surfaces past purchases.
  /// Safe to await at startup; resolves once existing entitlements have been
  /// queried (or a short timeout elapses).
  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) {},
    );

    // Product may legitimately not exist yet (not created in Play Console) —
    // that is fine, not a crash. notFoundIDs simply lists it.
    final resp = await _iap.queryProductDetails({ProductIds.removeAds});
    if (resp.productDetails.isNotEmpty) {
      _removeAdsProduct = resp.productDetails.first;
    }

    // Surface previously-owned purchases (delivered asynchronously via the
    // stream). Subscribe to the first entitlement event BEFORE restoring.
    final firstEntitlement = _entitlement.stream.first;
    await _iap.restorePurchases();
    try {
      await firstEntitlement.timeout(const Duration(seconds: 3));
    } catch (_) {
      // No past purchase surfaced in time → treated as not owned.
    }
  }

  void _onPurchaseUpdates(List<iap.PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != ProductIds.removeAds) {
        if (p.pendingCompletePurchase) _iap.completePurchase(p);
        continue;
      }
      switch (p.status) {
        case iap.PurchaseStatus.purchased:
        case iap.PurchaseStatus.restored:
          _removeAdsOwned = true;
          if (!_entitlement.isClosed) _entitlement.add(true);
          _complete(const PurchaseResult.alreadyOwned(ProductIds.removeAds));
          break;
        case iap.PurchaseStatus.error:
          _complete(PurchaseResult.failed(ProductIds.removeAds,
              message: p.error?.message));
          break;
        case iap.PurchaseStatus.canceled:
          _complete(const PurchaseResult.cancelled(ProductIds.removeAds));
          break;
        case iap.PurchaseStatus.pending:
          break; // leave the pending completer open
      }
      if (p.pendingCompletePurchase) _iap.completePurchase(p);
    }
  }

  void _complete(PurchaseResult result) {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(result);
    _pending = null;
  }

  @override
  Future<PurchaseResult> purchaseRemoveAds() async {
    if (!_available || _removeAdsProduct == null) {
      return const PurchaseResult(
        status: PurchaseStatus.notAvailable,
        productId: ProductIds.removeAds,
        message: 'Remove Ads is not available in the store yet.',
      );
    }
    if (_removeAdsOwned) {
      return const PurchaseResult.alreadyOwned(ProductIds.removeAds);
    }
    _pending = Completer<PurchaseResult>();
    final param = iap.PurchaseParam(productDetails: _removeAdsProduct!);
    await _iap.buyNonConsumable(purchaseParam: param);
    return _pending!.future; // completed by the purchase stream
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    if (!_available) return const [];
    await _iap.restorePurchases();
    return [
      if (_removeAdsOwned) const PurchaseResult.alreadyOwned(ProductIds.removeAds),
    ];
  }

  @override
  Future<bool> isRemoveAdsOwned() async => _removeAdsOwned;

  void dispose() {
    _sub?.cancel();
    if (!_entitlement.isClosed) _entitlement.close();
  }
}
