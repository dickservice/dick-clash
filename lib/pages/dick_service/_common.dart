import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/common/dick_service_models.dart';

class DickServiceScaffold extends StatelessWidget {
  const DickServiceScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
    );
  }
}

class DickServicePanel extends StatelessWidget {
  const DickServicePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: padding, child: child),
    );
  }
}

class DickServiceStateView extends StatelessWidget {
  const DickServiceStateView({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.onRetry,
    this.retryLabel,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel ?? '刷新'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SubscribeSummary extends StatelessWidget {
  const SubscribeSummary({super.key, required this.subscribe});
  final DickServiceSubscribe subscribe;

  @override
  Widget build(BuildContext context) {
    final ratio = subscribe.remainingTrafficRatio().clamp(0.0, 1.0);
    return DickServicePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subscribe.planName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text('剩余时间：${subscribe.remainingTimeText()}'),
          const SizedBox(height: 8),
          Text(
            '剩余流量：${subscribe.formattedRemainingTraffic} / ${subscribe.formattedTotalTraffic}',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: ratio),
        ],
      ),
    );
  }
}
