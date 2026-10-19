import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class HistaeWordmark extends StatelessWidget {
  const HistaeWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    return Semantics(
      label: AppStrings.of(context).messages.appOpeningHistae,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Image.asset(
          'assets/branding/histae-signature-$variant.png',
          width: 154,
          height: 37.8,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
