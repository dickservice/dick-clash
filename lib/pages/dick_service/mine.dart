import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'gift_card.dart';
import 'login.dart';
import 'orders.dart';
import 'shop.dart';
import 'tickets.dart';
import '_common.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';

class DickServiceMinePage extends StatefulWidget {
  const DickServiceMinePage({super.key, this.token});
  final String? token;

  @override
  State<DickServiceMinePage> createState() => _DickServiceMinePageState();
}

class _DickServiceMinePageState extends State<DickServiceMinePage> {
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
                      onPressed: () => _unsupported('重置流量'),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重置流量'),
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
                      onPressed: () => _unsupported('退出登录'),
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

  void _unsupported(String action) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$action暂不可用：请求体契约仍需动态捕获')));
}
