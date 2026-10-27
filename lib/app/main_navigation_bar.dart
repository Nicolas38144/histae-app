import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

enum MainTab { profile, discovery, matches }

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final destinations = [
      for (final tab in MainTab.values)
        switch (tab) {
          MainTab.discovery => (
            key: 'discovery',
            label: AppStrings.of(context).messages.mainNavigationBarFeed,
            icon: Icons.home_outlined,
            selected: Icons.home_rounded,
          ),
          MainTab.matches => (
            key: 'matches',
            label: AppStrings.of(context).messages.mainNavigationBarMatches,
            icon: Icons.forum_outlined,
            selected: Icons.forum_rounded,
          ),
          MainTab.profile => (
            key: 'profile',
            label: AppStrings.of(context).messages.mainNavigationBarProfile,
            icon: Icons.person_outline_rounded,
            selected: Icons.person_rounded,
          ),
        },
    ];
    int labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width.ceil() + 12;
      painter.dispose();
      return width;
    }

    final weights = [
      for (final destination in destinations)
        largeText ? labelWidth(destination.label) : 1,
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        flex: weights[index],
                        child: Semantics(
                          button: true,
                          selected: index == selectedIndex,
                          child: InkWell(
                            key: ValueKey(
                              'main-tab-${destinations[index].key}',
                            ),
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => onSelected(index),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: largeText ? 0 : 4,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    width: 38,
                                    height: 38,
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == selectedIndex
                                          ? colors.primary.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: index == selectedIndex
                                            ? colors.primary.withValues(
                                                alpha: 0.26,
                                              )
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Icon(
                                      index == selectedIndex
                                          ? destinations[index].selected
                                          : destinations[index].icon,
                                      size: 22,
                                      color: index == selectedIndex
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destinations[index].label,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: index == selectedIndex
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                          fontWeight: index == selectedIndex
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
