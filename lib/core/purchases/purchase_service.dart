/// Outcome status of a purchase request. Phase 1 *internal* contract.
///
/// Not assumed to map 1:1 to Play Billing / StoreKit. A later adapter maps real
/// SDK purchase states into these values.
enum PurchaseStatus {
  /// Purchase completed successfully and entitlement is now active.
  success,

  /// User already owns the product (treated as entitled).
  alreadyOwned,

  /// User cancelled the purchase flow.
  cancelled,

  /// Purchase is pending external confirmation (e.g. parental approval).
  pending,

  /// Purchase failed.
  failed,

  /// Product or billing unavailable on this device/build.
  notAvailable,
}

/// Stable identifiers for purchasable products in Phase 1.
class ProductIds {
  static const removeAds = 'remove_ads';
}

/// Result of a purchase or restore request. Stable Phase 1 contract.
class PurchaseResult {
  final PurchaseStatus status;
  final String productId;
  final String? message;

  const PurchaseResult({
    required this.status,
    required this.productId,
    this.message,
  });

  const PurchaseResult.success(this.productId)
      : status = PurchaseStatus.success,
        message = null;

  const PurchaseResult.alreadyOwned(this.productId)
      : status = PurchaseStatus.alreadyOwned,
        message = null;

  const PurchaseResult.cancelled(this.productId)
      : status = PurchaseStatus.cancelled,
        message = null;

  const PurchaseResult.failed(this.productId, {String? message})
      : status = PurchaseStatus.failed,
        message = message;

  /// True when the entitlement is active after this result.
  bool get isEntitled =>
      status == PurchaseStatus.success || status == PurchaseStatus.alreadyOwned;

  @override
  String toString() => 'PurchaseResult($status, $productId)';
}

/// App-wide purchases interface.
abstract class PurchaseService {
  /// Purchases the "remove ads" entitlement.
  Future<PurchaseResult> purchaseRemoveAds();

  /// Restores previously purchased entitlements.
  Future<List<PurchaseResult>> restorePurchases();

  /// Whether "remove ads" is currently owned.
  Future<bool> isRemoveAdsOwned();
}
