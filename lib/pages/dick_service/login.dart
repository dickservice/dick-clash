import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '_common.dart';

class DickServiceLoginPage extends ConsumerStatefulWidget {
  const DickServiceLoginPage({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  ConsumerState<DickServiceLoginPage> createState() =>
      _DickServiceLoginPageState();
}

class _DickServiceLoginPageState extends ConsumerState<DickServiceLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = DickServiceApi();
    try {
      final session = await api.login(email, password);
      final subscribe = await api.fetchSubscribe(session.token);
      final prefs = await preferences.sharedPreferencesCompleter.future;
      if (prefs == null) throw StateError('本地存储不可用');
      await prefs.setBool(DickServiceExpiryCacheStore.kBootstrapDone, true);
      await prefs.setString(kDickServiceAuthDataKey, session.token);
      await DickServiceExpiryCacheStore(prefs).saveSubscribe(
        DickServiceSubscribeCompat(
          planName: subscribe.planName,
          hasActivePlan: subscribe.hasActivePlan,
          expiredAtMs: subscribe.normalizedExpiredAt(),
          isExpired: subscribe.isExpired(),
        ),
      );
      if (subscribe.isTimeBasedExpired()) {
        if (mounted) setState(() => _error = '您的套餐已到期，请先续费后再使用');
        return;
      }
      await ref
          .read(profilesActionProvider.notifier)
          .addDickServiceBoundProfile();
      widget.onComplete?.call();
    } catch (error) {
      if (mounted) setState(() => _error = compactError(error));
    } finally {
      api.dio.close();
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
