import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import '_common.dart';

class DickServiceShopPage extends StatefulWidget {
  const DickServiceShopPage({super.key});

  @override
  State<DickServiceShopPage> createState() => _DickServiceShopPageState();
}

class _DickServiceShopPageState extends State<DickServiceShopPage> {
  final _api = DickServiceApi();
  late Future<List<DickServicePlan>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchPlans().then((m) {
        final raw = m['plans'] ?? m['data'];
        if (raw is! List) throw const FormatException('返回格式异常');
        return raw
            .whereType<Map>()
            .map((e) => DickServicePlan.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _api.dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DickServiceScaffold(
    title: '商城',
    actions: [
      IconButton(
        onPressed: _reload,
        tooltip: '刷新套餐',
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: FutureBuilder<List<DickServicePlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return DickServiceStateView(
            icon: Icons.storefront_outlined,
            title: '套餐加载失败',
            detail: '${snapshot.error}',
            onRetry: _reload,
          );
        }
        final plans = snapshot.data!;
        if (plans.isEmpty) {
          return const DickServiceStateView(
            icon: Icons.inventory_2_outlined,
            title: '暂无可购买套餐',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (_, i) =>
              _PlanCard(plan: plans[i], onBuy: () => _unsupported('创建订单并打开支付')),
        );
      },
    ),
  );

  void _unsupported(String action) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$action暂不可用：登录和支付请求体仍需动态捕获')));
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onBuy});
  final DickServicePlan plan;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) => DickServicePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
        if (plan.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(plan.content),
        ],
        if (plan.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            plan.tags.join(' · '),
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
        const SizedBox(height: 12),
        if (plan.priceOptions.isEmpty)
          const Text('暂无价格选项')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final price in plan.priceOptions)
                Chip(
                  label: Text(
                    '${price.formattedPrice}${price.period == null ? '' : ' · ${price.period}'}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onBuy,
          icon: const Icon(Icons.shopping_cart_checkout),
          label: const Text('创建订单并打开支付'),
        ),
      ],
    ),
  );
}
