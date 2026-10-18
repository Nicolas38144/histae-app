import 'package:flutter/material.dart';

import 'histae_button.dart';

/// Navigation shortcuts only. Availability and confirmation belong to the
/// subscription and credits screens, never to a shortcut in the feed.
class AccountBenefitsActions extends StatelessWidget {
  const AccountBenefitsActions({
    super.key,
    required this.onPremium,
    required this.onVideos,
  });

  final VoidCallback onPremium, onVideos;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final vertical = MediaQuery.textScalerOf(context).scale(14) > 20;
      final stacked = !vertical && constraints.maxWidth < 300;
      Widget label(IconData icon, String text) {
        final children = [Icon(icon, size: 21), Text(text)];
        return stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  children.first,
                  const SizedBox(height: 6),
                  children.last,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  children.first,
                  const SizedBox(width: 8),
                  children.last,
                ],
              );
      }

      final premium = Tooltip(
        message: 'Voir les formules Premium',
        child: HistaeButton(
          key: const Key('open-premium'),
          onPressed: onPremium,
          child: label(Icons.auto_awesome_outlined, 'Premium'),
        ),
      );
      final videos = Tooltip(
        message: 'Voir les vidéos et mes crédits',
        child: OutlinedButton(
          key: const Key('open-videos'),
          onPressed: onVideos,
          child: label(Icons.play_circle_outline, 'Vidéos'),
        ),
      );
      return vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [premium, const SizedBox(height: 12), videos],
            )
          : Row(
              children: [
                Expanded(child: premium),
                const SizedBox(width: 12),
                Expanded(child: videos),
              ],
            );
    },
  );
}
