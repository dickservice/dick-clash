import 'package:material_ui/material_ui.dart';

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
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail!.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel ?? '刷新'),
            ),
          ),
        ],
      ],
    );
  }
}
