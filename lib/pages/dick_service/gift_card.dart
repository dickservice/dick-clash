import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/common.dart';
import '_common.dart';

class DickServiceGiftCardPage extends StatefulWidget {
  const DickServiceGiftCardPage({super.key});

  @override
  State<DickServiceGiftCardPage> createState() =>
      _DickServiceGiftCardPageState();
}

class _DickServiceGiftCardPageState extends State<DickServiceGiftCardPage> {
  final _code = TextEditingController();
  final _api = DickServiceApi();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _code.dispose();
    _api.dio.close();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _result = '请输入兑换码');
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      final token = prefs?.getString(kDickServiceAuthDataKey);
      if (token == null || token.isEmpty) throw StateError('登录已失效，请重新登录');
      final result = await _api.redeemGiftCard(token, code);
      final subscribe = await _api.fetchSubscribe(token);
      if (prefs != null) {
        await DickServiceExpiryCacheStore(prefs).saveSubscribe(
          DickServiceSubscribeCompat(
            planName: subscribe.planName,
            hasActivePlan: subscribe.hasActivePlan,
            expiredAtMs: subscribe.normalizedExpiredAt(),
            isExpired: subscribe.isExpired(),
          ),
        );
      }
      if (mounted) setState(() => _result = result.summary);
    } catch (error) {
      if (mounted) setState(() => _result = compactError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DickServiceScaffold(
      title: '兑换码',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('兑换码兑换', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('请输入兑换码'),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: '兑换码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _redeem,
            icon: const Icon(Icons.card_giftcard),
            label: Text(_busy ? '兑换中...' : '立即兑换'),
          ),
          if (_result != null) ...[const SizedBox(height: 12), Text(_result!)],
        ],
      ),
    );
  }
}
