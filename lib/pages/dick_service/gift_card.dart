import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/common.dart';

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
    if (_busy) return;
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
      if (mounted) {
        context.showSnackBar(result.summary);
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) setState(() => _result = compactError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '兑换码兑换',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('输入官网兑换码，兑换成功后会刷新当前套餐与流量信息。'),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _redeem(),
              decoration: const InputDecoration(
                labelText: '兑换码',
                prefixIcon: Icon(Icons.card_giftcard),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _redeem,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard),
              label: Text(_busy ? '正在兑换...' : '立即兑换'),
            ),
          ],
        ),
      ),
    );
  }
}
