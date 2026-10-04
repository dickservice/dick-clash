// Port of AOT DickServiceExpiryCacheStore / DickServiceExpiryCache.
// Evidence: aot-dick-full/asm/fl_clash/common/dick_service_expiry_cache.dart
// and aot-dick-full/objs.txt (Duration@c14b91 = 0x141dd76000 us = 1 day).

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DickServiceSubscribeCompat {
  final String? planName;
  final bool hasActivePlan;
  final int? expiredAtMs;
  final bool isExpired;

  const DickServiceSubscribeCompat({
    this.planName,
    required this.hasActivePlan,
    this.expiredAtMs,
    required this.isExpired,
  });

  int? normalizedExpiredAt() => expiredAtMs;
  bool isExpiredNow() => isExpired;
}

class DickServiceExpiryCache {
  final int cachedExpiredAt;
  final int lastSubscribeSyncAt;
  final int lastLocalCheckAt;
  final bool cachedHasActivePlan;
  final String cachedPlanName;
  final bool expiredLock;
  final bool signatureValid;
  final bool isPastLocalCheckWindow;

  const DickServiceExpiryCache({
    required this.cachedExpiredAt,
    required this.lastSubscribeSyncAt,
    required this.lastLocalCheckAt,
    required this.cachedHasActivePlan,
    required this.cachedPlanName,
    required this.expiredLock,
    required this.signatureValid,
    required this.isPastLocalCheckWindow,
  });

  bool get isExpired {
    // AOT fields 0x17..0x27 represent lock/integrity/clock/sync/plan state.
    if (expiredLock || !signatureValid || isPastLocalCheckWindow) return true;
    if (lastSubscribeSyncAt <= 0 || !cachedHasActivePlan) return true;
    return _isExpiredAt(cachedExpiredAt);
  }

  bool shouldRefresh({bool force = false}) {
    if (force) return true;
    if (lastSubscribeSyncAt <= 0) return true;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSubscribeSyncAt),
    );
    // AOT compares DateTime.difference against Duration@c14b91. The object
    // dump gives 0x141dd76000 microseconds, exactly Duration(days: 1).
    return elapsed >= const Duration(days: 1);
  }

  static bool _isExpiredAt(int expiredAt) {
    if (expiredAt <= 0) return false;
    // AOT multiplies the seconds value by 1000 before DateTime construction,
    // then returns !expiration.isAfter(now), i.e. expiration <= now.
    final expMs = expiredAt * 1000;
    final exp = DateTime.fromMillisecondsSinceEpoch(expMs);
    return !exp.isAfter(DateTime.now());
  }
}

class DickServiceExpiryCacheStore {
  static const kCachedExpiredAt = 'dick_service_cached_expired_at';
  static const kCachedHasActivePlan = 'dick_service_cached_has_active_plan';
  static const kCachedPlanName = 'dick_service_cached_plan_name';
  static const kLastSubscribeSyncAt = 'dick_service_last_subscribe_sync_at';
  static const kLastLocalCheckAt = 'dick_service_last_local_check_at';
  static const kBootstrapDone = 'dick_service_bootstrap_done';
  static const kExpiredLock = 'dick_service_expired_lock';
  static const kSubscribeCacheSignature =
      'dick_service_subscribe_cache_signature';

  static const kCacheVersion = 'dick-service-subscribe-cache-v1';

  final SharedPreferences prefs;
  DickServiceExpiryCacheStore(this.prefs);

  static String _signature(
    int expiredAt,
    bool hasActivePlan,
    String planName,
    int lastSyncAt,
    int lastLocalCheckAt,
  ) {
    final m = <String, Object>{
      'v': kCacheVersion,
      'expired_at': expiredAt,
      'has_active_plan': hasActivePlan,
      'plan_name': planName,
      'last_sync_at': lastSyncAt,
      'last_local_check_at': lastLocalCheckAt,
      'client': kCacheVersion,
    };
    final json = jsonEncode(m);
    final bytes = utf8.encode(json);
    return sha256.convert(bytes).toString();
  }

  Future<void> saveSubscribe(DickServiceSubscribeCompat s) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiredAt = s.normalizedExpiredAt() ?? 0;
    final hasActivePlan = s.hasActivePlan;
    final planName = s.planName ?? '';
    await prefs.setInt(kCachedExpiredAt, expiredAt);
    await prefs.setBool(kCachedHasActivePlan, hasActivePlan);
    await prefs.setString(kCachedPlanName, planName);
    await prefs.setInt(kLastSubscribeSyncAt, nowMs);
    await prefs.setInt(kLastLocalCheckAt, nowMs);
    if (s.isExpiredNow()) {
      await prefs.setBool(kExpiredLock, true);
    } else {
      await prefs.remove(kExpiredLock);
    }
    final sig = _signature(expiredAt, hasActivePlan, planName, nowMs, nowMs);
    await prefs.setString(kSubscribeCacheSignature, sig);
  }

  // AOT method name is `clear` (asm ...:687d50). Keep the reconstruction's
  // older public spelling as a forwarding alias for existing callers.
  Future<void> clear() async {
    await prefs.remove(kCachedExpiredAt);
    await prefs.remove(kCachedHasActivePlan);
    await prefs.remove(kCachedPlanName);
    await prefs.remove(kLastSubscribeSyncAt);
    await prefs.remove(kLastLocalCheckAt);
    await prefs.remove(kSubscribeCacheSignature);
    await prefs.setBool(kExpiredLock, false);
  }

  Future<void> clearSubscribeCache() => clear();

  Future<DickServiceExpiryCache> load() async {
    final cachedExpiredAt = prefs.getInt(kCachedExpiredAt) ?? 0;
    final cachedHasActivePlan = prefs.getBool(kCachedHasActivePlan) ?? false;
    final cachedPlanName = prefs.getString(kCachedPlanName) ?? '';
    final lastSubscribeSyncAt = prefs.getInt(kLastSubscribeSyncAt) ?? 0;
    final lastLocalCheckAt = prefs.getInt(kLastLocalCheckAt) ?? 0;
    final expiredLock = prefs.getBool(kExpiredLock) ?? false;
    final storedSig = prefs.getString(kSubscribeCacheSignature);

    // AOT treats an entirely absent cache as not tampered; freshness/plan
    // checks still make it refresh immediately.
    bool signatureValid = true;
    if (lastSubscribeSyncAt > 0 || cachedExpiredAt > 0) {
      final expected = _signature(
        cachedExpiredAt,
        cachedHasActivePlan,
        cachedPlanName,
        lastSubscribeSyncAt,
        lastLocalCheckAt,
      );
      signatureValid = storedSig == expected;
    } else if (lastLocalCheckAt > 0) {
      final expected = _signature(
        cachedExpiredAt,
        cachedHasActivePlan,
        cachedPlanName,
        lastSubscribeSyncAt,
        lastLocalCheckAt,
      );
      signatureValid = storedSig == expected;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool isPastLocalCheckWindow = false;
    if (lastLocalCheckAt > 0) {
      // AOT checks (now + 60000) < lastLocalCheckAt. Values are epoch
      // milliseconds, so this detects a clock rollback greater than 60s.
      isPastLocalCheckWindow = nowMs + 60000 < lastLocalCheckAt;
      if (!signatureValid) {
        await prefs.setBool(kExpiredLock, true);
      } else {
        // keep signature for future loads
        await _saveLastLocalCheck(
          cachedExpiredAt,
          cachedHasActivePlan,
          cachedPlanName,
          lastSubscribeSyncAt,
          lastLocalCheckAt,
        );
      }
    }

    return DickServiceExpiryCache(
      cachedExpiredAt: cachedExpiredAt,
      lastSubscribeSyncAt: lastSubscribeSyncAt,
      lastLocalCheckAt: lastLocalCheckAt,
      cachedHasActivePlan: cachedHasActivePlan,
      cachedPlanName: cachedPlanName,
      // AOT field 0x17 is storedLock || signatureInvalid || clockRollback.
      expiredLock: expiredLock || !signatureValid || isPastLocalCheckWindow,
      signatureValid: signatureValid,
      isPastLocalCheckWindow: isPastLocalCheckWindow,
    );
  }

  Future<void> _saveLastLocalCheck(
    int expiredAt,
    bool hasActivePlan,
    String planName,
    int lastSyncAt,
    int lastLocalCheckAt,
  ) async {
    await prefs.setInt(kLastLocalCheckAt, lastLocalCheckAt);
    final sig = _signature(
      expiredAt,
      hasActivePlan,
      planName,
      lastSyncAt,
      lastLocalCheckAt,
    );
    await prefs.setString(kSubscribeCacheSignature, sig);
  }

  int get cachedExpiredAt => prefs.getInt(kCachedExpiredAt) ?? 0;
  bool get cachedHasActivePlan => prefs.getBool(kCachedHasActivePlan) ?? false;
  String get cachedPlanName => prefs.getString(kCachedPlanName) ?? '';
  int get lastSubscribeSyncAt => prefs.getInt(kLastSubscribeSyncAt) ?? 0;
  int get lastLocalCheckAt => prefs.getInt(kLastLocalCheckAt) ?? 0;
  bool get expiredLock => prefs.getBool(kExpiredLock) ?? false;

  Future<void> setBootstrapDone(bool v) => prefs.setBool(kBootstrapDone, v);
  bool get bootstrapDone => prefs.getBool(kBootstrapDone) ?? false;
}
