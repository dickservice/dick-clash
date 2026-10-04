import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'package:fl_clash/common/dick_service_expiry_cache.dart';
import 'gift_card.dart';
import 'login.dart';
import 'orders.dart';
import 'shop.dart';
import 'tickets.dart';
import '_common.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'payment_webview.dart';

class DickServiceMinePage extends ConsumerStatefulWidget {
  const DickServiceMinePage({super.key, this.token});
  final String? token;

  @override
  ConsumerState<DickServiceMinePage> createState() =>
      _DickServiceMinePageState();
}

class _DickServiceMinePageState extends ConsumerState<DickServiceMinePage> {
  final _api = DickServiceApi();
  late Future<DickServiceSubscribe> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _loadSubscribe();
    });
  }

  Future<DickServiceSubscribe> _loadSubscribe() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录 Dick Service');
    return _api.fetchSubscribe(token);
  }

  @override
  void dispose() {
    _api.dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DickServiceScaffold(
      title: '我的',
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: FutureBuilder<DickServiceSubscribe>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return DickServiceStateView(
              icon: Icons.account_circle_outlined,
              title: '我的信息加载失败',
              detail: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final subscribe = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SubscribeSummary(subscribe: subscribe),
              DickServicePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账号提醒',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (subscribe.shouldWarnRenewal())
                      const Text('套餐即将到期，请及时续费。续费仅增加时长，不增加当月流量。'),
                    if (subscribe.shouldWarnTrafficReset())
                      Text(
                        '流量剩余不足 10%：剩余 ${subscribe.formattedRemainingTraffic}。重置流量仅重置当月流量，不增加时长。',
                      ),
                  ],
                ),
              ),
              DickServicePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DickServiceLoginPage(),
                        ),
                      ),
                      child: const Text('登录 Dick Service'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DickServiceShopPage(),
                        ),
                      ),
                      child: const Text('商城'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DickServiceOrdersPage(token: widget.token),
                        ),
                      ),
                      child: const Text('我的订单'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DickServiceTicketsPage(token: widget.token),
                        ),
                      ),
                      child: const Text('工单'),
                    ),
                    Text(
                      '账户操作',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DickServiceGiftCardPage(),
                        ),
                      ),
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('兑换码兑换'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _resetTraffic(subscribe),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重置流量'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetSubscribe,
                      icon: const Icon(Icons.security_update_good),
                      label: const Text('重置订阅链接'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DickServiceShopPage(),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('商城'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DickServiceOrdersPage(token: widget.token),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('我的订单'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DickServiceTicketsPage(token: widget.token),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('工单'),
                    ),
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('退出登录'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _token() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录已失效，请重新登录');
    return token;
  }

  Future<void> _resetTraffic(DickServiceSubscribe subscribe) async {
    final price = subscribe.resetPrice ?? 0;
    if (subscribe.planId <= 0 || price <= 0) {
      _showMessage('当前套餐没有可用的重置流量价格，请到官网处理');
      return;
    }
    try {
      final token = await _token();
      final order = await _api.createTrafficResetOrder(token, subscribe.planId);
      final checkout = await _api.checkoutOrder(token, order.tradeNo, 1);
      if (mounted) {
        await openDickServicePaymentPage(
          context,
          checkout: checkout,
          tradeNo: order.tradeNo,
        );
        _reload();
      }
    } catch (error) {
      _showMessage(compactError(error));
    }
  }

  Future<void> _resetSubscribe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置订阅链接'),
        content: const Text('重置后旧订阅链接将失效，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.resetSecurity(await _token());
      await ref
          .read(profilesActionProvider.notifier)
          .addDickServiceBoundProfile();
      _showMessage('订阅已重置，软件内配置已自动刷新');
      _reload();
    } catch (error) {
      _showMessage(compactError(error));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后将删除 Dick Service 授权和绑定配置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (prefs == null) return;
    final token = prefs.getString(kDickServiceAuthDataKey);
    if (token != null && token.isNotEmpty) {
      try {
        await _api.fetchSubscribeUrlFromAuthData(token);
      } catch (_) {}
    }
    final profile = ref.read(profilesProvider).dickServiceBoundProfile;
    await prefs.remove(kDickServiceAuthDataKey);
    await prefs.remove('dick_service_last_account_alert');
    await prefs.setBool(DickServiceExpiryCacheStore.kBootstrapDone, false);
    await DickServiceExpiryCacheStore(prefs).clear();
    if (profile != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profile.id);
    }
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const DickServiceLoginPage()),
      (_) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
