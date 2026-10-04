import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
  bool? _complete;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (!mounted) return;
    setState(() {
      // AOT reads dick_service_auth_data here. Normal Clash profiles do not
      // satisfy the Dick Service bootstrap gate.
      final auth = prefs?.getString(kDickServiceAuthDataKey);
      _complete = auth != null && auth.isNotEmpty;
    });
    // TODO(capture): account-alert deduplication and exact warning thresholds.
    // Subscription validation is performed by the inner expiry gate.
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
  bool _checking = false;
  bool _pendingForce = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkSubscription());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkSubscription(force: true));
    }
  }

  Future<void> _checkSubscription({bool force = false}) async {
    if (_checking) {
      _pendingForce |= force;
      return;
    }
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
      // Never apply an old account response after a concurrent logout/login.
      if (prefs.getString(kDickServiceAuthDataKey) != auth) return;
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
          () => _message = subscribe.isTimeBasedExpired()
              ? '您的套餐已到期，请续费以继续使用'
              : null,
        );
      }
    } catch (_) {
      // TODO(capture): exact offline grace policy. Retain observed cache state;
      // a transport failure alone must not manufacture an expired account.
    } finally {
      _checking = false;
      if (_pendingForce && mounted) {
        _pendingForce = false;
        unawaited(_checkSubscription(force: true));
      }
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
    if (_message == null) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                const Text('套餐已到期'),
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () =>
                      ref.read(systemActionProvider.notifier).handleExit(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: _openRenewPage,
                  child: const Text('续费'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.api == null) _api.dio.close();
    super.dispose();
  }
}
