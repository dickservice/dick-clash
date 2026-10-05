import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';
import 'shop.dart';

/// AOT login.dart: 0x889464 build, 0x97abd8 load, 0x889558 complete.
class DickServiceBootstrapGate extends ConsumerStatefulWidget {
  const DickServiceBootstrapGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DickServiceBootstrapGate> createState() =>
      _BootstrapGateState();
}

class _BootstrapGateState extends ConsumerState<DickServiceBootstrapGate> {
  static const _lastAccountAlertKey = 'dick_service_last_account_alert';

  late final DickServiceApi _api = DickServiceApi();
  bool? _complete;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (!mounted) return;
    final profiles = ref.read(profilesProvider);
    final auth = prefs?.getString(kDickServiceAuthDataKey);
    setState(() {
      // AOT _load 0x97abd8 / closure 0x97ad58: _complete is
      // bootstrapDone || profiles.hasDickServiceBound. Auth presence only
      // gates the subsequent _checkAccountStatus call, not completion itself
      // (auth-empty still clears the loading state via the closure).
      final bootstrapDone =
          prefs?.getBool(DickServiceExpiryCacheStore.kBootstrapDone) ?? false;
      _complete = bootstrapDone || profiles.hasDickServiceBound;
    });
    if (auth != null && auth.isNotEmpty && prefs != null) {
      unawaited(_checkAccountStatus(prefs, auth));
    }
  }

  Future<void> _checkAccountStatus(SharedPreferences prefs, String auth) async {
    final store = DickServiceExpiryCacheStore(prefs);
    final cache = await store.load();
    if (!cache.shouldRefresh()) return;

    // The AOT bootstrap check passes the auth token read during _load into
    // fetchSubscribe and does not perform a second account-state branch here.
    final subscribe = await _api.fetchSubscribe(auth);
    await store.saveSubscribe(
      DickServiceSubscribeCompat(
        planName: subscribe.planName,
        hasActivePlan: subscribe.hasActivePlan,
        expiredAtMs: subscribe.normalizedExpiredAt(),
        isExpired: subscribe.isExpired(),
      ),
    );

    final warnings = <String>[];
    if (subscribe.shouldWarnRenewal()) {
      warnings.add('套餐${subscribe.remainingTimeText()}，请及时续费。续费仅增加时长，不增加当月流量。');
    }
    if (subscribe.shouldWarnTrafficReset()) {
      warnings.add('流量剩余不足 10%，建议重置流量。重置流量仅重置当月流量，不增加时长。');
    }
    if (warnings.isEmpty || !mounted) return;

    final message = warnings.join('\n\n');
    if (prefs.getString(_lastAccountAlertKey) == message) return;
    await prefs.setString(_lastAccountAlertKey, message);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('账号状态提醒'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_complete == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_complete == false) {
      return DickServiceLoginPage(
        onComplete: () {
          if (mounted) setState(() => _complete = true);
        },
      );
    }
    return DickServiceExpiryGate(child: widget.child);
  }
}

/// AOT expiry_gate.dart: 0x6859d8 lifecycle and 0x685a50 check.
/// UI wiring is reconstructed; core-stop/cancel/offline contracts remain capture TODOs.
class DickServiceExpiryGate extends ConsumerStatefulWidget {
  const DickServiceExpiryGate({super.key, required this.child, this.api});
  final Widget child;
  final DickServiceApi? api;

  @override
  ConsumerState<DickServiceExpiryGate> createState() => _ExpiryGateState();
}

class _ExpiryGateState extends ConsumerState<DickServiceExpiryGate>
    with WidgetsBindingObserver {
  late final DickServiceApi _api = widget.api ?? DickServiceApi();
  Timer? _timer;
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(_checkSubscription()),
    );
    unawaited(_checkSubscription());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkSubscription(force: true));
    }
  }

  Future<void> _checkSubscription({bool force = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      if (prefs == null) return;
      final store = DickServiceExpiryCacheStore(prefs);
      final auth = prefs.getString(kDickServiceAuthDataKey);
      if (auth == null || auth.isEmpty) {
        await store.clearSubscribeCache();
        if (mounted) setState(() => _message = null);
        return;
      }
      final cache = await store.load();
      if (cache.isExpired && mounted) {
        setState(
          () =>
              _message = (!cache.signatureValid || cache.isPastLocalCheckWindow)
              ? '账号状态校验异常，请联网重新登录或续费后再使用'
              : '您的套餐已到期，请续费以继续使用',
        );
      }
      if (!cache.shouldRefresh(force: force)) return;
      final subscribe = await _api.fetchSubscribe(auth);
      await store.saveSubscribe(
        DickServiceSubscribeCompat(
          planName: subscribe.planName,
          hasActivePlan: subscribe.hasActivePlan,
          expiredAtMs: subscribe.normalizedExpiredAt(),
          isExpired: subscribe.isExpired(),
        ),
      );
      if (mounted) {
        setState(
          () => _message = subscribe.isExpired() ? '您的套餐已到期，请续费以继续使用' : null,
        );
      }
    } catch (_) {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      if (prefs == null) return;
      final cache = await DickServiceExpiryCacheStore(prefs).load();
      if (cache.isExpired && mounted) {
        setState(
          () =>
              _message = (!cache.signatureValid || cache.isPastLocalCheckWindow)
              ? '账号状态校验异常，请联网重新登录或续费后再使用'
              : '您的套餐已到期，请续费以继续使用',
        );
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _openRenewPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DickServiceShopPage()),
    );
    if (mounted) await _checkSubscription(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_message != null)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: PopScope(
                canPop: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock,
                              size: 52,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '套餐已到期',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => ref
                                        .read(systemActionProvider.notifier)
                                        .handleExit(),
                                    child: const Text('取消'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _openRenewPage,
                                    child: const Text('续费'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (widget.api == null) _api.dio.close();
    super.dispose();
  }
}
