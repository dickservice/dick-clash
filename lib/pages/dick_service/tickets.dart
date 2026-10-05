import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import '_common.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';
import 'package:fl_clash/common/print.dart';

class DickServiceTicketsPage extends StatefulWidget {
  const DickServiceTicketsPage({super.key, this.token});
  final String? token;
  @override
  State<DickServiceTicketsPage> createState() => _DickServiceTicketsPageState();
}

class _DickServiceTicketsPageState extends State<DickServiceTicketsPage> {
  final _api = DickServiceApi();
  late Future<List<DickServiceTicket>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadRows();
    });
    await _future;
  }

  Future<List<DickServiceTicket>> _loadRows() async {
    return _api.fetchTickets(await _authData());
  }

  Future<String> _authData() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) {
      throw StateError('请先在商城登录/购买一次，再查看工单');
    }
    return token;
  }

  @override
  void dispose() {
    _api.dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DickServiceScaffold(
    title: '工单',
    actions: [
      IconButton(
        onPressed: _openCreate,
        tooltip: '创建工单',
        icon: const Icon(Icons.add),
      ),
      IconButton(
        onPressed: _reload,
        tooltip: '刷新',
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<DickServiceTicket>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return DickServiceStateView(
              icon: Icons.support_agent,
              title: '工单加载失败',
              detail: '${snapshot.error}',
              onRetry: _reload,
              retryLabel: '重试',
            );
          }
          if (snapshot.data!.isEmpty) {
            return DickServiceStateView(
              icon: Icons.support_agent,
              title: '暂无工单',
              onRetry: _openCreate,
              retryLabel: '新建工单',
            );
          }
          final tickets = snapshot.data!;
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final ticket = tickets[index];
              return DickServicePanel(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${ticket.level}')),
                  title: Text(ticket.subject),
                  subtitle: Text(
                    '${ticket.replyStatusText}\n${ticket.createdAt}',
                  ),
                  isThreeLine: true,
                  trailing: Text(ticket.status == 0 ? '处理中' : '已关闭'),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateTicketSheet(api: _api, authData: _authData),
    );
    if (created == true && mounted) await _reload();
  }
}

class _CreateTicketSheet extends StatefulWidget {
  const _CreateTicketSheet({required this.api, required this.authData});
  final DickServiceApi api;
  final Future<String> Function() authData;

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  int _level = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = '请填写工单标题和内容');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.createTicket(
        await widget.authData(),
        level: _level,
        message: message,
        subject: subject,
      );
      if (mounted) Navigator.of(context).pop(true);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('新建工单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: '工单标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '工单内容'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: '优先级'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('低')),
              DropdownMenuItem(value: 1, child: Text('中')),
              DropdownMenuItem(value: 2, child: Text('高')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _level = value!),
          ),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '提交中...' : '提交工单'),
          ),
        ],
      ),
    ),
  );
}
