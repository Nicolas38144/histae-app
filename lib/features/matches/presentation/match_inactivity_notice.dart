import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';

class MatchInactivityNotice extends StatelessWidget {
  const MatchInactivityNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return ExpansionTile(
      key: const PageStorageKey('matches-inactivity-info'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.info_outline_rounded, size: 20),
      title: Text(
        text.matchesInactivityInfo,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        Text(
          text.matchesInactivityPolicy,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
