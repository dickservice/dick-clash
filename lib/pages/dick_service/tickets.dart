import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import '_common.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/dick_service_profile.dart';

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

  void _reload() {
    setState(() {
      _future = _loadRows();
    });
  }

  Future<List<DickServiceTicket>> _loadRows() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = widget.token ?? prefs?.getString(kDickServiceAuthDataKey);
    if (token == null || token.isEmpty) throw StateError('登录 Dick Service');
    final m = await _api.fetchTickets(token);
    final raw = m['tickets'] ?? m['data'];
    if (raw is! List) throw const FormatException('返回格式异常');
    return raw
        .whereType<Map>()
        .map((e) => DickServiceTicket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
        onPressed: _reload,
        tooltip: '刷新',
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: FutureBuilder<List<DickServiceTicket>>(
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
          );
        }
        if (snapshot.data!.isEmpty) {
          return const DickServiceStateView(
            icon: Icons.support_agent,
            title: '暂无工单',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final ticket in snapshot.data!)
              DickServicePanel(
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
              ),
          ],
        );
      },
    ),
  );
}
