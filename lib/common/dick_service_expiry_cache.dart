// Port of AOT DickServiceExpiryCacheStore / DickServiceExpiryCache — static reconstruction.
// Evidence: aot-dick-full/asm/fl_clash/common/dick_service_expiry_cache.dart
// Classes 2664, 2665. Do NOT treat as production contract until capture.

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
    if (expiredLock) return true;
    if (!signatureValid) return false;
    // AOT: expiredLock || signatureValid && _isExpiredAt(cachedExpiredAt)
    // Keep conservative: if signature invalid, don't treat as expired.
    if (cachedHasActivePlan && _isExpiredAt(cachedExpiredAt)) return true;
    if (!cachedHasActivePlan) return true;
    return false;
  }

  bool shouldRefresh({bool force = false}) {
    if (force) return true;
    if (lastSubscribeSyncAt <= 0) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // AOT difference check threshold appears ~60s for local check window,
    // but refresh interval is not fully verified — use 1h as safe default.
    // TODO(capture): verify exact refresh interval from dynamic capture.
    const refreshIntervalSec = 3600;
    return nowSec - lastSubscribeSyncAt >= refreshIntervalSec;
  }

  static bool _isExpiredAt(int expiredAt) {
    if (expiredAt <= 0) return false;
    final expMs = expiredAt * 1000;
    // AOT uses DateTime._validateMilliseconds + isAfter(now)
    try {
      final exp = DateTime.fromMillisecondsSinceEpoch(expMs);
      return DateTime.now().isAfter(exp);
    } catch (_) {
      return false;
    }
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
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiredAt = s.normalizedExpiredAt() ?? 0;
    final hasActivePlan = s.hasActivePlan;
    final planName = s.planName ?? '';
    await prefs.setInt(kCachedExpiredAt, expiredAt);
    await prefs.setBool(kCachedHasActivePlan, hasActivePlan);
    await prefs.setString(kCachedPlanName, planName);
    await prefs.setInt(kLastSubscribeSyncAt, nowSec);
    await prefs.setInt(kLastLocalCheckAt, nowSec);
    if (s.isExpiredNow()) {
      await prefs.setBool(kExpiredLock, true);
    } else {
      await prefs.remove(kExpiredLock);
    }
    final sig = _signature(expiredAt, hasActivePlan, planName, nowSec, nowSec);
    await prefs.setString(kSubscribeCacheSignature, sig);
  }

  Future<void> clearSubscribeCache() async {
    await prefs.remove(kCachedExpiredAt);
    await prefs.remove(kCachedHasActivePlan);
    await prefs.remove(kCachedPlanName);
    await prefs.remove(kLastSubscribeSyncAt);
    await prefs.remove(kLastLocalCheckAt);
    await prefs.remove(kSubscribeCacheSignature);
    await prefs.setBool(kExpiredLock, false);
  }

  Future<DickServiceExpiryCache> load() async {
    final cachedExpiredAt = prefs.getInt(kCachedExpiredAt) ?? 0;
    final cachedHasActivePlan = prefs.getBool(kCachedHasActivePlan) ?? false;
    final cachedPlanName = prefs.getString(kCachedPlanName) ?? '';
    final lastSubscribeSyncAt = prefs.getInt(kLastSubscribeSyncAt) ?? 0;
    final lastLocalCheckAt = prefs.getInt(kLastLocalCheckAt) ?? 0;
    final expiredLock = prefs.getBool(kExpiredLock) ?? false;
    final storedSig = prefs.getString(kSubscribeCacheSignature);

    bool signatureValid = false;
    if (cachedExpiredAt > 0 || lastSubscribeSyncAt > 0) {
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

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    bool isPastLocalCheckWindow = false;
    if (lastLocalCheckAt > 0) {
      // AOT checks now + 60000 < lastLocalCheck? keep simple window check
      isPastLocalCheckWindow = nowSec > lastLocalCheckAt + 60;
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
      expiredLock: expiredLock || (!signatureValid && isPastLocalCheckWindow),
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
