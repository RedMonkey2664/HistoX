import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:histox/app/admin_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/core/services/purchases_service.dart';
import 'package:histox/core/services/revenuecat_service.dart';

class _ConnectedStore implements PurchasesService {
  @override
  bool get isConfigured => true;

  @override
  Future<PriceLoad> prices() async => const PriceLoad(PriceStatus.ok);

  @override
  Future<bool> purchase(ProPlan plan) async => false;

  @override
  Future<bool> restore() async => false;

  @override
  Future<bool> hasPro() async => false;

  @override
  Stream<bool> get proChanges => const Stream<bool>.empty();
}

/// A connected store whose entitlement the test can flip.
class _LiveStore extends _ConnectedStore {
  final StreamController<bool> changes = StreamController<bool>();

  @override
  Stream<bool> get proChanges => changes.stream;
}

void main() {
  test(
    'with no store connected, the preview unlock grants Pro for the session',
    () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(proAccessProvider).hasPro, isFalse);
      c.read(proAccessProvider.notifier).unlockPreview();
      expect(c.read(proAccessProvider).hasPro, isTrue);
      expect(c.read(proAccessProvider).purchased, isFalse);
    },
  );

  test('once a store is connected, the preview unlock does nothing', () {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        purchasesServiceProvider.overrideWithValue(_ConnectedStore()),
      ],
    );
    addTearDown(c.dispose);

    c.read(proAccessProvider.notifier).unlockPreview();
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });

  test('the unconnected store refuses to sell or restore', () async {
    const StoreNotConnectedService store = StoreNotConnectedService();
    expect((await store.prices()).hasPrices, isFalse);
    expect(
      store.purchase(ProPlan.yearly),
      throwsA(isA<StoreUnavailableException>()),
    );
    expect(store.restore(), throwsA(isA<StoreUnavailableException>()));
  });

  test(
    'with no RevenueCat key in the build, the store stays unconnected',
    () async {
      final PurchasesService store = await RevenueCatPurchasesService.connect();
      expect(store.isConfigured, isFalse);
    },
  );

  test('a store-side entitlement change reaches every Pro gate', () async {
    final _LiveStore store = _LiveStore();
    final ProviderContainer c = ProviderContainer(
      overrides: [purchasesServiceProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);

    expect(c.read(proAccessProvider).hasPro, isFalse);
    store.changes.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proAccessProvider).hasPro, isTrue);

    // An expiry takes it away again.
    store.changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });

  test('a release build can never grant Pro without a store', () {
    // The guard is a compile-time constant, so this locks its definition:
    // if someone loosens it, a release build shipped without RevenueCat keys
    // would hand the whole campaign and the full profile away for free.
    // Web is the public demo and has nothing to sell, so it keeps the
    // unlock; a phone release build must never have it.
    expect(kPreviewUnlockAllowed, !kReleaseMode || kIsWeb);
  });

  test('the preview unlock is refused once a store is connected', () {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        purchasesServiceProvider.overrideWithValue(_ConnectedStore()),
      ],
    );
    addTearDown(c.dispose);

    c.read(proAccessProvider.notifier).unlockPreview();
    expect(c.read(proAccessProvider).previewUnlocked, isFalse);
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });

  test('admin mode is off in a release build unless forced at build time', () {
    // Same shape of guard as the preview unlock: if this ever becomes true
    // in release by default, the settings sheet hands out every Pro level.
    expect(AdminMode.enabled, !kReleaseMode || AdminMode.isForcedIntoRelease);
    expect(AdminMode.isForcedIntoRelease, isFalse,
        reason: 'tests must not run with HISTOX_ADMIN forced on');
  });

  test('the admin unlock is a separate door from the preview unlock', () {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        purchasesServiceProvider.overrideWithValue(_ConnectedStore()),
      ],
    );
    addTearDown(c.dispose);

    // With a store connected the preview affordance stays shut...
    c.read(proAccessProvider.notifier).unlockPreview();
    expect(c.read(proAccessProvider).hasPro, isFalse);

    // ...while admin still works, because it is for testing the locked and
    // unlocked states on a build that has a store.
    c.read(proAccessProvider.notifier).unlockForAdmin();
    expect(c.read(proAccessProvider).hasPro, isTrue);

    c.read(proAccessProvider.notifier).relockForAdmin();
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });

  group('the paywall is told why there are no prices', () {
    test('no key in the build reports notConfigured, not an empty list', () async {
      const StoreNotConnectedService store = StoreNotConnectedService();
      final PriceLoad load = await store.prices();

      expect(load.status, PriceStatus.notConfigured);
      expect(load.hasPrices, isFalse);
      expect(load.message, contains('NOT CONNECTED'));
    });

    test('each failure says something different', () {
      // The point of the type: a missing offering, missing products and a
      // dead network used to be indistinguishable on screen.
      final List<PriceStatus> failures = <PriceStatus>[
        for (final PriceStatus s in PriceStatus.values)
          if (s != PriceStatus.ok) s,
      ];
      final Set<String> messages = <String>{
        for (final PriceStatus s in failures)
          if (PriceLoad(s).message case final String m) m,
      };

      expect(messages, hasLength(failures.length));
      // And "ok with nothing in it" is its own case, not silence.
      expect(const PriceLoad(PriceStatus.ok).message, isNotNull);
    });

    test('prices present means no message to show', () {
      const PriceLoad load = PriceLoad.ok(<PlanPrice>[
        PlanPrice(plan: ProPlan.yearly, priceLabel: 'Rs 1,499'),
      ]);
      expect(load.hasPrices, isTrue);
      expect(load.message, isNull);
    });
  });
}
