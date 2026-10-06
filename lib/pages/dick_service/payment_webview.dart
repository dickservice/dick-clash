import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'package:fl_clash/common/dialog.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '_common.dart';

class DickServicePaymentWebViewPage extends StatefulWidget {
  const DickServicePaymentWebViewPage({
    super.key,
    required this.checkout,
    this.tradeNo,
  });
  final DickServiceCheckout checkout;
  final String? tradeNo;

  @override
  State<DickServicePaymentWebViewPage> createState() =>
      _DickServicePaymentWebViewPageState();
}

class _DickServicePaymentWebViewPageState
    extends State<DickServicePaymentWebViewPage> {
  late final WebViewController _controller;
  bool _canGoBack = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }
            dialogs.openUrl(request.url);
            return NavigationDecision.prevent;
          },
          onProgress: (progress) {
            setState(() => _progress = progress);
          },
          onPageFinished: (_) => _updateCanGoBack(),
        ),
      );
    final html = widget.checkout.html;
    if (html != null && html.isNotEmpty) {
      _controller.loadHtmlString(html);
    } else {
      _controller.loadRequest(Uri.parse(widget.checkout.url!));
    }
  }

  Future<void> _updateCanGoBack() async {
    final value = await _controller.canGoBack();
    if (mounted) setState(() => _canGoBack = value);
  }

  Future<bool> _onPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _updateCanGoBack();
      return false;
    }
    return true;
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
    await _updateCanGoBack();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_canGoBack,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _onPop();
    },
    child: DickServiceScaffold(
      title: '订单支付',
      actions: [
        IconButton(
          onPressed: _controller.reload,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '关闭支付',
          icon: const Icon(Icons.close),
        ),
      ],
      body: Column(
        children: [
          Row(
            children: [
              if (widget.tradeNo != null && widget.tradeNo!.isNotEmpty)
                Expanded(child: Text('订单号：${widget.tradeNo}'))
              else
                const Spacer(),
              if (_canGoBack)
                TextButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
            ],
          ),
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    ),
  );
}

Future<void> openDickServicePaymentPage(
  BuildContext context, {
  required DickServiceCheckout checkout,
  String? tradeNo,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          DickServicePaymentWebViewPage(checkout: checkout, tradeNo: tradeNo),
    ),
  );
}
