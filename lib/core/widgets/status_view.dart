import 'package:flutter/material.dart';

class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    this.reference,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final String? reference;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(height: 12),
      Text(message),
      if (action != null) ...[const SizedBox(height: 24), action!],
      if (reference != null) ...[
        const SizedBox(height: 24),
        SelectableText(
          reference!,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
