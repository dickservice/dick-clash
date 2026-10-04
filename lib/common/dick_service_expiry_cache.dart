// Port of AOT DickServiceExpiryCacheStore — preference keys and save/load verified.
import 'package:shared_preferences/shared_preferences.dart';

class DickServiceSubscribeCompat {
  final String? planName;
  final bool hasActivePlan;
  final int? expiredAtMs; // normalizedExpiredAt if available
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

class DickServiceExpiryCacheStore {
  static const kCachedExpiredAt = 'dick_service_cached_expired_at';
  static const kCachedHasActivePlan = 'dick_service_cached_has_active_plan';
  static const kCachedPlanName = 'dick_service_cached_plan_name';
  static const kLastSubscribeSyncAt = 'dick_service_last_subscribe_sync_at';
  static const kLastLocalCheckAt = 'dick_service_last_local_check_at';
  static const kBootstrapDone = 'dick_service_bootstrap_done';
  static const kExpiredLock = 'dick_service_expired_lock';

  final SharedPreferences prefs;
  DickServiceExpiryCacheStore(this.prefs);

  Future<void> saveSubscribe(DickServiceSubscribeCompat s) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt(kCachedExpiredAt, s.normalizedExpiredAt() ?? 0);
    await prefs.setBool(kCachedHasActivePlan, s.hasActivePlan);
    await prefs.setString(kCachedPlanName, s.planName ?? '');
    await prefs.setInt(kLastSubscribeSyncAt, nowSec);
    await prefs.setInt(kLastLocalCheckAt, nowSec);
    if (s.isExpiredNow()) {
      await prefs.setBool(kExpiredLock, true);
    }
  }

  Future<void> clearSubscribeCache() async {
    await prefs.remove(kCachedExpiredAt);
    await prefs.remove(kCachedHasActivePlan);
    await prefs.remove(kCachedPlanName);
    await prefs.remove(kLastSubscribeSyncAt);
  }

  int get cachedExpiredAt => prefs.getInt(kCachedExpiredAt) ?? 0;
  bool get cachedHasActivePlan => prefs.getBool(kCachedHasActivePlan) ?? false;
  String get cachedPlanName => prefs.getString(kCachedPlanName) ?? '';
  int get lastSubscribeSyncAt => prefs.getInt(kLastSubscribeSyncAt) ?? 0;
  bool get expiredLock => prefs.getBool(kExpiredLock) ?? false;

  Future<void> setBootstrapDone(bool v) => prefs.setBool(kBootstrapDone, v);
  bool get bootstrapDone => prefs.getBool(kBootstrapDone) ?? false;
}
