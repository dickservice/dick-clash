import 'package:material_ui/material_ui.dart';
import '_common.dart';

/// Payment WebView is intentionally not implemented: AOT shows a WebView
/// contract, but the fork has no validated WebView dependency or policy.
class DickServicePaymentWebViewPage extends StatelessWidget {
  const DickServicePaymentWebViewPage({
    super.key,
    required this.url,
    this.tradeNo,
  });
  final String url;
  final String? tradeNo;

  @override
  Widget build(BuildContext context) => DickServiceScaffold(
    title: '订单支付',
    body: DickServiceStateView(
      icon: Icons.payment_outlined,
      title: '支付页面暂不可用',
      detail: '订单号：${tradeNo ?? '--'}\n支付 WebView 合同仍需动态捕获，未加载未经验证的地址。',
    ),
  );
}

Future<void> openDickServicePaymentPage(
  BuildContext context, {
  required String url,
  String? tradeNo,
}) async {
  throw UnimplementedError(
    'payment WebView contract not verified from static AOT - needs dynamic capture',
  );
}
