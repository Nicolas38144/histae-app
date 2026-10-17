import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

class HistaeWordmark extends StatelessWidget {
  const HistaeWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: HistaeTokens.serif,
      fontWeight: FontWeight.w700,
      fontSize: 29,
      height: 1,
      letterSpacing: -1.7,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Semantics(
      label: 'Histae',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Histae', style: style),
            Text(
              '.',
              style: style.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
