import 'package:flutter/material.dart';

import 'histae_button.dart';

/// A subscription entry point. Unknown or stale plans use a neutral label
/// until the server confirms whether an upgrade is relevant.
class AccountBenefitsActions extends StatelessWidget {
  const AccountBenefitsActions({
    super.key,
    required this.isPremium,
    required this.onSubscription,
  });

  final bool? isPremium;
  final VoidCallback onSubscription;

  @override
  Widget build(BuildContext context) => HistaeButton.icon(
    key: const Key('profile-subscription'),
    onPressed: onSubscription,
    icon: Icon(
      isPremium == false
          ? Icons.auto_awesome_outlined
          : Icons.manage_accounts_outlined,
    ),
    label: Text(isPremium == false ? 'Premium' : 'Mon abonnement'),
  );
}
