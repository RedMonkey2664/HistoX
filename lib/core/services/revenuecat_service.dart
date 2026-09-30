import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_service.dart';

/// RevenueCat's public SDK keys, one per store, supplied at build time:
///
///     flutter run --dart-define-from-file=config/revenuecat.json
///
/// (see `config/revenuecat.example.json`). These are RevenueCat's *public*
/// app-specific keys — designed to ship inside the app — but they are still
/// kept out of the repository so each environment chooses its own.
///
/// With no key for the current platform the app runs exactly as before, on
/// [StoreNotConnectedService].
abstract final class RevenueCatKeys {
  static const String apple = String.fromEnvironment('RC_APPLE_KEY');
  static const String google = String.fromEnvironment('RC_GOOGLE_KEY');
  static const String web = String.fromEnvironment('RC_WEB_KEY');

  /// RevenueCat's Test Store key. When set it wins on every platform, so the
  /// whole purchase flow can be exercised before any store is set up.
  ///
  /// Two places may use it, and [current] enforces the difference:
  /// development builds, and the public **web** demo, which sells nothing and
  /// needs a live offering to show a real paywall with real prices. A phone
  /// release build may never use it, because that build goes to a store where
  /// purchases have to be real.
  static const String test = String.fromEnvironment('RC_TEST_KEY');

  /// The entitlement every Pro gate checks (MONETIZATION.md).
  ///
  /// Configurable because the dashboard is the source of truth and it does
  /// not have to agree with a constant compiled in here. The HistoX project
  /// calls it `histox_pro`; get this wrong and a purchase completes, the
  /// money moves, and `entitlements.active` never contains the key the app
  /// is looking for — so Pro silently never unlocks.
  static const String entitlement = String.fromEnvironment(
    'RC_ENTITLEMENT',
    defaultValue: 'pro',
  );

  /// Which key this build is using, named but never shown. Diagnostics may
  /// say "test store"; they may not print the key.
  static String describeCurrent() {
    final String? k = current();
    if (k == null) return 'none';
    if (k.startsWith('test_')) return 'test store';
    if (k.startsWith('appl_')) return 'apple';
    if (k.startsWith('goog_')) return 'google';
    return 'configured';
  }

  /// The key for the platform this build is running on, or null.
  static String? current() {
    // The Test Store never takes real money. A phone release build must not
    // be able to reach it however it was invoked — that build goes to a
    // store, where purchases have to be real. The web build is the public
    // demo and sells nothing, so it may use the Test Store: that is what
    // lets the demo show the dashboard's real offerings and prices.
    if (test.isNotEmpty && (!kReleaseMode || kIsWeb)) return test;
    final String key = kIsWeb
        ? web
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => apple,
            TargetPlatform.android => google,
            _ => '',
          };
    return key.isEmpty ? null : key;
  }
}

/// The real store, through RevenueCat (MONETIZATION.md, Phase 8).
///
/// Maps RevenueCat's current offering onto the paywall's two plans — the
/// offering's *annual* package is YEARLY and its *monthly* package is
/// MONTHLY — and reads Pro from the [RevenueCatKeys.entitlement]
/// entitlement. Prices are the store's
/// own localised strings; nothing here formats a price.
class RevenueCatPurchasesService implements PurchasesService {
  RevenueCatPurchasesService._() {
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
  }

  /// Configures the SDK if this build has a key for the platform, and
  /// otherwise — or if configuring fails — returns the unconnected store, so
  /// a missing key can never stop the app from starting.
  static Future<PurchasesService> connect() async {
    final String? key = RevenueCatKeys.current();
    if (key == null) return const StoreNotConnectedService();
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(key));
      return RevenueCatPurchasesService._();
    } on Object catch (error) {
      debugPrint('RevenueCat could not be configured: $error');
      return const StoreNotConnectedService();
    }
  }

  final StreamController<bool> _pro = StreamController<bool>.broadcast();

  void _onCustomerInfo(CustomerInfo info) => _pro.add(_isPro(info));

  static bool _isPro(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatKeys.entitlement);

  @override
  bool get isConfigured => true;

  @override
  Stream<bool> get proChanges => _pro.stream;

  Future<Offering?> _offering() async =>
      (await Purchases.getOfferings()).current;

  static Package? _packageFor(Offering offering, ProPlan plan) =>
      switch (plan) {
        ProPlan.yearly => offering.annual,
        ProPlan.monthly => offering.monthly,
      };

  @override
  Future<PriceLoad> prices() async {
    try {
      final Offering? offering = await _offering();
      if (offering == null) {
        _log('no current offering: set one in the RevenueCat dashboard');
        return const PriceLoad(PriceStatus.noOffering);
      }

      final List<PlanPrice> plans = <PlanPrice>[
        for (final ProPlan plan in ProPlan.values)
          if (_packageFor(offering, plan) case final Package p)
            PlanPrice(
              plan: plan,
              priceLabel: p.storeProduct.priceString,
              perMonthLabel: plan == ProPlan.yearly
                  ? p.storeProduct.pricePerMonthString
                  : null,
            ),
      ];

      _log(
        'offering "${offering.identifier}" with '
        '${offering.availablePackages.length} packages; '
        'annual=${offering.annual?.storeProduct.priceString ?? "-"} '
        'monthly=${offering.monthly?.storeProduct.priceString ?? "-"}',
      );

      // An offering with neither package is a dashboard that is not finished:
      // the products are missing, or the store has not approved them yet.
      if (plans.isEmpty) return const PriceLoad(PriceStatus.noProducts);
      return PriceLoad.ok(plans);
    } on PlatformException catch (e) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(e);
      _log('offerings failed: $code ${e.message}');
      return PriceLoad(
        code == PurchasesErrorCode.networkError
            ? PriceStatus.networkError
            : PriceStatus.storeError,
      );
    }
  }

  /// Debug-only. Never logs a key, a receipt or anything identifying.
  void _log(String message) {
    if (kDebugMode) debugPrint('[RevenueCat] $message');
  }

  @override
  Future<bool> purchase(ProPlan plan) async {
    final Offering? offering = await _offering();
    final Package? package = offering == null
        ? null
        : _packageFor(offering, plan);
    if (package == null) {
      throw const PurchaseFailure(
        'That plan is not available in your store yet.',
      );
    }
    try {
      final PurchaseResult result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return _isPro(result.customerInfo);
    } on PlatformException catch (e) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(e);
      // Backing out of the store sheet is a choice, not an error.
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      throw PurchaseFailure(_messageFor(code, e));
    }
  }

  @override
  Future<bool> restore() async {
    try {
      return _isPro(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      throw PurchaseFailure(
        _messageFor(PurchasesErrorHelper.getErrorCode(e), e),
      );
    }
  }

  @override
  Future<bool> hasPro() async {
    try {
      return _isPro(await Purchases.getCustomerInfo());
    } on PlatformException catch (e) {
      debugPrint('RevenueCat customer info unavailable: ${e.message}');
      return false;
    }
  }

  static String _messageFor(PurchasesErrorCode code, PlatformException e) =>
      switch (code) {
        PurchasesErrorCode.networkError =>
          'No connection to the store. Check your connection and try again.',
        PurchasesErrorCode.paymentPendingError =>
          'Payment pending. Pro unlocks as soon as the store confirms it.',
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own Pro. Tap Restore purchases.',
        _ => e.message ?? 'The purchase could not be completed.',
      };
}
