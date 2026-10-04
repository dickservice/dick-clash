import 'package:material_ui/material_ui.dart';
import '_common.dart';

class DickServiceLoginPage extends StatefulWidget {
  const DickServiceLoginPage({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<DickServiceLoginPage> createState() => _DickServiceLoginPageState();
}

class _DickServiceLoginPageState extends State<DickServiceLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      throw UnimplementedError(
        'login body not verified from static AOT - needs dynamic capture',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录暂不可用：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DickServiceScaffold(
      title: '登录 Dick Service',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Dick Service',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('验证账号后自动导入你的专属订阅。'),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '账号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.login),
            label: Text(_busy ? '正在导入...' : '登录并导入订阅'),
          ),
          const SizedBox(height: 12),
          Text(
            '登录契约仍需动态捕获，页面不会伪造成功或保存授权。',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
