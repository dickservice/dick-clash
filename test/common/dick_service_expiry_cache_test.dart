import 'package:fl_clash/common/dick_service_expiry_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'a saved active subscription round-trips without an expiry lock',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = DickServiceExpiryCacheStore(prefs);
      final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      await store.saveSubscribe(
        DickServiceSubscribeCompat(
          planName: 'Example',
          hasActivePlan: true,
          expiredAtMs: future,
          isExpired: false,
        ),
      );

      final cache = await store.load();
      expect(cache.signatureValid, isTrue);
      expect(cache.expiredLock, isFalse);
      expect(cache.isExpired, isFalse);
      expect(cache.shouldRefresh(), isFalse);
    },
  );

  test('refresh interval uses the AOT one-day duration', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = DickServiceExpiryCache(
      cachedExpiredAt: 0,
      lastSubscribeSyncAt: now - const Duration(hours: 23).inMilliseconds,
      lastLocalCheckAt: now,
      cachedHasActivePlan: true,
      cachedPlanName: 'Example',
      expiredLock: false,
      signatureValid: true,
      isPastLocalCheckWindow: false,
    );
    final stale = DickServiceExpiryCache(
      cachedExpiredAt: 0,
      lastSubscribeSyncAt: now - const Duration(hours: 25).inMilliseconds,
      lastLocalCheckAt: now,
      cachedHasActivePlan: true,
      cachedPlanName: 'Example',
      expiredLock: false,
      signatureValid: true,
      isPastLocalCheckWindow: false,
    );

    expect(fresh.shouldRefresh(), isFalse);
    expect(stale.shouldRefresh(), isTrue);
  });

  test('tampering with signed cache data locks the cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = DickServiceExpiryCacheStore(prefs);
    final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    await store.saveSubscribe(
      DickServiceSubscribeCompat(
        planName: 'Example',
        hasActivePlan: true,
        expiredAtMs: future,
        isExpired: false,
      ),
    );

    await prefs.setString(
      DickServiceExpiryCacheStore.kCachedPlanName,
      'Changed',
    );
    final cache = await store.load();
    expect(cache.signatureValid, isFalse);
    expect(cache.expiredLock, isTrue);
    expect(cache.isExpired, isTrue);
  });

  test('partial timestamp state is treated as tampered', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = DickServiceExpiryCacheStore(prefs);
    await prefs.setInt(DickServiceExpiryCacheStore.kLastLocalCheckAt, 1);

    final cache = await store.load();
    expect(cache.signatureValid, isFalse);
    expect(cache.expiredLock, isTrue);
    expect(cache.isExpired, isTrue);
  });

  test('clock rollback locks an otherwise valid cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = DickServiceExpiryCacheStore(prefs);
    final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    await store.saveSubscribe(
      DickServiceSubscribeCompat(
        planName: 'Example',
        hasActivePlan: true,
        expiredAtMs: future,
        isExpired: false,
      ),
    );
    await prefs.setInt(
      DickServiceExpiryCacheStore.kLastLocalCheckAt,
      DateTime.now().millisecondsSinceEpoch + 120000,
    );

    final cache = await store.load();
    expect(cache.isPastLocalCheckWindow, isTrue);
    expect(cache.expiredLock, isTrue);
    expect(cache.isExpired, isTrue);
    expect(prefs.getBool(DickServiceExpiryCacheStore.kExpiredLock), isTrue);
  });

  test('clear removes signed state and resets the persisted lock', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = DickServiceExpiryCacheStore(prefs);
    await prefs.setBool(DickServiceExpiryCacheStore.kExpiredLock, true);
    await prefs.setInt(DickServiceExpiryCacheStore.kCachedExpiredAt, 123);

    await store.clear();

    expect(
      prefs.containsKey(DickServiceExpiryCacheStore.kCachedExpiredAt),
      isFalse,
    );
    expect(prefs.getBool(DickServiceExpiryCacheStore.kExpiredLock), isFalse);
  });
}
