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
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _loadRows();
    });
  }

  Future<List<DickServiceUserOrder>> _loadRows() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录 Dick Service');
    final m = await _api.fetchOrders(token);
    final raw = m['orders'] ?? m['data'];
    if (raw is! List) throw const FormatException('返回格式异常');
    return raw
        .whereType<Map>()
        .map((e) => DickServiceUserOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    body: FutureBuilder<List<DickServiceUserOrder>>(
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
          );
        }
        if (snapshot.data!.isEmpty) {
          return const DickServiceStateView(
            icon: Icons.receipt_long_outlined,
            title: '暂无订单',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final order in snapshot.data!)
              _OrderCard(
                order: order,
                onPay: () => _pay(order),
                onCancel: () => _cancel(order),
              ),
          ],
        );
      },
    ),
  );
  Future<String> _token() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录 Dick Service');
    return token;
  }

  Future<void> _pay(DickServiceUserOrder order) async {
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
        if (mounted) _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(compactError(error))));
      }
    }
  }

  Future<void> _cancel(DickServiceUserOrder order) async {
    try {
      await _api.cancelOrder(await _token(), order.tradeNo);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(compactError(error))));
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onPay,
    required this.onCancel,
  });
  final DickServiceUserOrder order;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => DickServicePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.name.isEmpty ? order.plan : order.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(label: Text(order.statusText)),
          ],
        ),
        const SizedBox(height: 8),
        Text('订单号：${order.tradeNo}'),
        if (order.period.isNotEmpty) Text(order.period),
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
              OutlinedButton(onPressed: onPay, child: const Text('继续支付')),
            if (order.status == 1)
              TextButton(onPressed: onCancel, child: const Text('取消支付')),
          ],
        ),
      ],
    ),
  );
}
