import 'package:material_ui/material_ui.dart';
import '_common.dart';

/// The AOT page is backed by an unverified POST request. Keep the form useful
/// for static replication without inventing a redeem contract or success.
class DickServiceGiftCardPage extends StatefulWidget {
  const DickServiceGiftCardPage({super.key});

  @override
  State<DickServiceGiftCardPage> createState() =>
      _DickServiceGiftCardPageState();
}

class _DickServiceGiftCardPageState extends State<DickServiceGiftCardPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _redeem() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('兑换暂不可用：请求体契约仍需动态捕获')));
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
            onPressed: _redeem,
            icon: const Icon(Icons.card_giftcard),
            label: const Text('立即兑换'),
          ),
        ],
      ),
    );
  }
}
