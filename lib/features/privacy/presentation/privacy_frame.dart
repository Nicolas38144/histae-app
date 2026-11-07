import 'package:flutter/material.dart';

import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_scaffold.dart';

class PrivacyFrame extends StatelessWidget {
  const PrivacyFrame({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: HistaeTokens.pagePadding,
            children: children,
          ),
        ),
      ),
    ),
  );
}
