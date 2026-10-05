import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import '_common.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';
import 'package:fl_clash/common/print.dart';
import 'payment_webview.dart';

class DickServiceOrdersPage extends StatefulWidget {
  const DickServiceOrdersPage({super.key, this.token});
  final String? token;
  @override
  State<DickServiceOrdersPage> createState() => _DickServiceOrdersPageState();
}

class _DickServiceOrdersPageState extends State<DickServiceOrdersPage> {
  final _api = DickServiceApi();
  late Future<List<DickServiceUserOrder>> _future;
  bool _paying = false;
  bool _cancelling = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadRows();
    });
    await _future;
  }

  Future<List<DickServiceUserOrder>> _loadRows() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('请先在商城登录/下单一次，再查看订单');
    return _api.fetchOrders(token);
  }

  @override
  void dispose() {
    _api.dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DickServiceScaffold(
    title: '我的订单',
    actions: [
      IconButton(
        onPressed: _reload,
        tooltip: '刷新订单',
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<DickServiceUserOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return DickServiceStateView(
              icon: Icons.receipt_long_outlined,
              title: '订单加载失败',
              detail: '${snapshot.error}',
              onRetry: _reload,
              retryLabel: '重试',
            );
          }
          if (snapshot.data!.isEmpty) {
            return DickServiceStateView(
              icon: Icons.receipt_long_outlined,
              title: '暂无订单',
              onRetry: _reload,
              retryLabel: '刷新',
            );
          }
          final orders = snapshot.data!;
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final order = orders[index];
              return _OrderCard(
                order: order,
                paying: _paying,
                cancelling: _cancelling,
                onPay: _paying ? null : () => _pay(order),
                onCancel: _cancelling ? null : () => _cancel(order),
              );
            },
          );
        },
      ),
    ),
  );
  Future<String> _token() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录已过期，请回到商城重新登录');
    return token;
  }

  Future<void> _pay(DickServiceUserOrder order) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final checkout = await _api.checkoutOrder(
        await _token(),
        order.tradeNo,
        1,
      );
      if (mounted) {
        await openDickServicePaymentPage(
          context,
          checkout: checkout,
          tradeNo: order.tradeNo,
        );
        if (mounted) await _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(compactError(error))));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancel(DickServiceUserOrder order) async {
    if (_cancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订单'),
        content: Text('确定取消订单 ${order.tradeNo}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await _api.cancelOrder(await _token(), order.tradeNo);
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(compactError(error))));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.paying,
    required this.cancelling,
    required this.onPay,
    required this.onCancel,
  });
  final DickServiceUserOrder order;
  final bool paying;
  final bool cancelling;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;
  String get _title {
    if (order.planName.isNotEmpty) return order.planName;
    return '未命名套餐';
  }

  @override
  Widget build(BuildContext context) => DickServicePanel(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(label: Text(order.statusText)),
          ],
        ),
        const SizedBox(height: 8),
        Text('订单号：${order.tradeNo}'),
        if (order.period case final period? when period.isNotEmpty)
          Text(period),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                order.formattedAmount,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (order.status == 0)
              FilledButton.icon(
                onPressed: onPay,
                icon: paying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: Text(paying ? '正在打开...' : '继续支付'),
              ),
            if (order.status == 1)
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close),
                label: Text(cancelling ? '取消中...' : '取消支付'),
              ),
          ],
        ),
      ],
    ),
  );
}
