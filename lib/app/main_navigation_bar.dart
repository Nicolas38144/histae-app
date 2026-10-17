import 'package:flutter/material.dart';

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
    const destinations = [
      (
        key: 'discovery',
        label: 'Feed',
        icon: Icons.home_outlined,
        selected: Icons.home_rounded,
      ),
      (
        key: 'matches',
        label: 'Matchs',
        icon: Icons.forum_outlined,
        selected: Icons.forum_rounded,
      ),
      (
        key: 'profile',
        label: 'Profil',
        icon: Icons.person_outline_rounded,
        selected: Icons.person_rounded,
      ),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: colors.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
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
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            index == selectedIndex
                                ? destinations[index].selected
                                : destinations[index].icon,
                            color: index == selectedIndex
                                ? colors.primary
                                : colors.onSurfaceVariant,
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
    );
  }
}
