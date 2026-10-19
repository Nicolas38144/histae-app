import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

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
    final destinations = [
      (
        key: 'discovery',
        label: AppStrings.of(context).messages.mainNavigationBarFeed,
        icon: Icons.home_outlined,
        selected: Icons.home_rounded,
      ),
      (
        key: 'matches',
        label: AppStrings.of(context).messages.mainNavigationBarMatches,
        icon: Icons.forum_outlined,
        selected: Icons.forum_rounded,
      ),
      (
        key: 'profile',
        label: AppStrings.of(context).messages.mainNavigationBarProfile,
        icon: Icons.person_outline_rounded,
        selected: Icons.person_rounded,
      ),
    ];
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          color: colors.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: index == selectedIndex,
                    child: InkWell(
                      key: ValueKey('main-tab-${destinations[index].key}'),
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 30,
                              decoration: BoxDecoration(
                                color: index == selectedIndex
                                    ? colors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
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
                            const SizedBox(height: 5),
                            Text(
                              destinations[index].label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium
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
        ),
      ),
    );
  }
}
