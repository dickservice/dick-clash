import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'package:fl_clash/common/dick_service_expiry_cache.dart';
import 'gift_card.dart';
import 'login.dart';
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

  Future<void> _reload() async {
    setState(() {
      _future = _loadSubscribe();
    });
    await _future;
  }

  Future<DickServiceSubscribe> _loadSubscribe() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) {
      throw StateError('请先在商城登录/购买一次，再查看我的套餐');
    }
    return _api.fetchSubscribe(token);
  }

  Future<void> _redeemGiftCard() async {
    final redeemed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DickServiceGiftCardPage(),
    );
    if (redeemed == true && mounted) await _reload();
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
          onPressed: _redeemGiftCard,
          tooltip: '兑换码',
          icon: const Icon(Icons.card_giftcard),
        ),
        IconButton(
          onPressed: _logout,
          tooltip: '退出登录',
          icon: const Icon(Icons.logout),
        ),
        IconButton(
          onPressed: _reload,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<DickServiceSubscribe>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MineErrorView(error: snapshot.error!, onRetry: _reload);
            }
            final subscribe = snapshot.data!;
            final showRenewalAlert = subscribe.shouldWarnRenewal();
            final showTrafficAlert = subscribe.shouldWarnTrafficReset();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PlanSummaryCard(subscribe: subscribe),
                if (showRenewalAlert || showTrafficAlert) ...[
                  const SizedBox(height: 12),
                  _AccountAlertCard(
                    subscribe: subscribe,
                    onResetTraffic: () => _resetTraffic(subscribe),
                  ),
                ],
                const SizedBox(height: 12),
                _TrafficCard(subscribe: subscribe),
                const SizedBox(height: 12),
                _MineActionCard(
                  onRedeemGiftCard: _redeemGiftCard,
                  onResetSubscribe: _resetSubscribe,
                  onLogout: _logout,
                ),
              ],
            );
          },
        ),
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
        await _reload();
      }
    } catch (error) {
      _showMessage(compactError(error));
    }
  }

  Future<void> _resetSubscribe() async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置订阅'),
        content: const Text('重置后旧订阅链接会立刻失效。软件内已绑定账号，会自动使用新订阅链接，无需手动重新导入。'),
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
    if (firstConfirmed != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再次确认'),
        content: const Text('确定要重置订阅链接吗？旧链接失效后，其他设备需要重新获取订阅。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重置'),
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
      await _reload();
    } catch (error) {
      _showMessage(compactError(error));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('会清除本机保存的官网授权，并移除当前导入的订阅配置。下次打开需要重新登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (prefs == null) return;
    final token = prefs.getString(kDickServiceAuthDataKey);
    String? resolvedSubscribeUrl;
    if (token != null && token.isNotEmpty) {
      try {
        resolvedSubscribeUrl = await _api.fetchSubscribeUrlFromAuthData(token);
      } catch (_) {}
    }
    // AOT 0x8b5298 removes only profiles whose URL equals the URL resolved
    // from the saved authorization data.
    final candidates = ref
        .read(profilesProvider)
        .dickServiceLogoutCandidates(resolvedSubscribeUrl);
    await prefs.remove(kDickServiceAuthDataKey);
    await prefs.remove('dick_service_last_account_alert');
    await prefs.setBool(DickServiceExpiryCacheStore.kBootstrapDone, false);
    await DickServiceExpiryCacheStore(prefs).clear();
    for (final profile in candidates) {
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

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.subscribe});

  final DickServiceSubscribe subscribe;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前套餐',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscribe.planName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoTile(
                  icon: Icons.schedule_outlined,
                  label: '剩余时间',
                  value: subscribe.remainingTimeText(),
                ),
                if (subscribe.resetDay != null)
                  _InfoTile(
                    icon: Icons.restart_alt,
                    label: '重置流量',
                    value: '${subscribe.resetDay} 天后',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.subscribe});

  final DickServiceSubscribe subscribe;

  @override
  Widget build(BuildContext context) {
    final usedRatio = subscribe.transferEnable <= 0
        ? 0.0
        : ((subscribe.u + subscribe.d) / subscribe.transferEnable).clamp(
            0.0,
            1.0,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '剩余流量',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subscribe.formattedRemainingTraffic,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: usedRatio),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(label: Text('已用 ${subscribe.formattedUsedTraffic}')),
                Chip(label: Text('总量 ${subscribe.formattedTotalTraffic}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountAlertCard extends StatelessWidget {
  const _AccountAlertCard({
    required this.subscribe,
    required this.onResetTraffic,
  });

  final DickServiceSubscribe subscribe;
  final VoidCallback onResetTraffic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '账号提醒',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (subscribe.shouldWarnRenewal()) ...[
              const SizedBox(height: 8),
              Text(
                '套餐即将到期：${subscribe.remainingTimeText()}，请及时续费。续费仅增加时长，不增加当月流量。',
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
            ],
            if (subscribe.shouldWarnTrafficReset()) ...[
              const SizedBox(height: 8),
              Text(
                '流量剩余不足 10%：剩余 ${subscribe.formattedRemainingTraffic}。重置流量仅重置当月流量，不增加时长。',
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onResetTraffic,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重置流量'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MineActionCard extends StatelessWidget {
  const _MineActionCard({
    required this.onRedeemGiftCard,
    required this.onResetSubscribe,
    required this.onLogout,
  });

  final VoidCallback onRedeemGiftCard;
  final VoidCallback onResetSubscribe;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('兑换码兑换'),
            subtitle: const Text('对接官网兑换码，兑换成功后自动刷新套餐信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onRedeemGiftCard,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security_update_good),
            title: const Text('重置订阅'),
            subtitle: const Text('重置旧订阅链接；软件内配置会继续绑定账号并自动刷新'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onResetSubscribe,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: errorColor),
            title: Text('退出登录', style: TextStyle(color: errorColor)),
            subtitle: const Text('清除本机授权和当前导入的订阅配置'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _MineErrorView extends StatelessWidget {
  const _MineErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.account_circle_outlined, size: 56, color: colors.error),
        const SizedBox(height: 12),
        Text(
          '我的信息加载失败',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$error'.replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.outline),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('重试')),
        ),
      ],
    );
  }
}
