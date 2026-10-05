import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';
import 'package:fl_clash/common/print.dart';
import '_common.dart';
import 'payment_webview.dart';

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

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchPlans();
    });
    await _future;
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
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<DickServicePlan>>(
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
            return DickServiceStateView(
              icon: Icons.inventory_2_outlined,
              title: '暂无可购买套餐',
              onRetry: _reload,
              retryLabel: '刷新',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _PlanCard(plan: plans[i], onBuy: () => _openPurchase(plans[i])),
          );
        },
      ),
    ),
  );

  Future<void> _openPurchase(DickServicePlan plan) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _PurchaseSheet(api: _api, plan: plan, paymentContext: context),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onBuy});
  final DickServicePlan plan;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) => DickServicePanel(
    margin: EdgeInsets.zero,
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
          onPressed: plan.priceOptions.isEmpty ? null : onBuy,
          icon: const Icon(Icons.shopping_cart_checkout),
          label: const Text('创建订单并打开支付'),
        ),
      ],
    ),
  );
}

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({
    required this.api,
    required this.plan,
    required this.paymentContext,
  });
  final DickServiceApi api;
  final DickServicePlan plan;
  final BuildContext paymentContext;

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  final _coupon = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late DickServicePriceOption _price = widget.plan.priceOptions.first;
  int _method = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _coupon.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final period = _price.period;
    if (period == null || period.isEmpty) {
      setState(() => _error = '购买周期不可用');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      var token = prefs?.getString(kDickServiceAuthDataKey);
      if (token == null || token.isEmpty) {
        final email = _email.text.trim();
        final password = _password.text;
        if (email.isEmpty || password.isEmpty) {
          throw StateError('请输入官网账号和密码');
        }
        final session = await widget.api.login(email, password);
        token = session.token;
        if (prefs != null) {
          await prefs.setString(kDickServiceAuthDataKey, token);
        }
      }
      final coupon = _coupon.text.trim();
      final order = await widget.api.createOrder(
        token,
        period,
        widget.plan.id,
        couponCode: coupon.isEmpty ? null : coupon,
      );
      if (order.tradeNo.isEmpty) throw StateError('订单号返回为空');
      final checkout = await widget.api.checkoutOrder(
        token,
        order.tradeNo,
        _method,
      );
      if (!mounted) return;
      final paymentContext = widget.paymentContext;
      if (!paymentContext.mounted) return;
      Navigator.of(context).pop();
      await openDickServicePaymentPage(
        paymentContext,
        checkout: checkout,
        tradeNo: order.tradeNo,
      );
    } catch (error) {
      if (mounted) setState(() => _error = compactError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.plan.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前选择：${_price.period ?? '--'} · ${_price.formattedPrice}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DickServicePriceOption>(
              initialValue: _price,
              decoration: const InputDecoration(labelText: '购买周期'),
              items: [
                for (final price in widget.plan.priceOptions)
                  DropdownMenuItem(
                    value: price,
                    child: Text(
                      '${price.period ?? '--'} · ${price.formattedPrice}',
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _price = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: '支付方式'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('支付宝')),
                DropdownMenuItem(value: 2, child: Text('微信')),
                DropdownMenuItem(value: 3, child: Text('USDT')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _method = value!),
            ),
            const SizedBox(height: 12),
            Text(
              '首次购买需要登录官网账号；登录成功后会保存授权，后续购买不再弹账号密码。',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '账号（首次购买填写）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码（首次购买填写）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coupon,
              decoration: const InputDecoration(labelText: '优惠码（可选）'),
            ),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text(_busy ? '正在创建订单...' : '创建订单并打开支付'),
            ),
          ],
        ),
      ),
    ),
  );
}
