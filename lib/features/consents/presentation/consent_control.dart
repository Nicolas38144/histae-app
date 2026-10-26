import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../domain/consent_state.dart';
import 'consent_strings.dart';

/// Presents a document acknowledgement or a withdrawable consent.
class ConsentControl extends StatelessWidget {
  const ConsentControl({
    super.key,
    required this.consent,
    required this.value,
    required this.onChanged,
    required this.onOpen,
  });
  final PublicConsent consent;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final strings = AppStrings.of(context);
    final title = Text(
      strings.consentTitle(consent.type),
      style: Theme.of(context).textTheme.titleMedium,
    );
    final renewal = consent.granted && !consent.current;
    final document = HistaeButton.text(
      onPressed: onOpen,
      child: Text(strings.readDocument),
    );
    final key = Key(consent.type.wireName);
    if (!consent.type.withdrawable) {
      return Column(
        key: consent.current
            ? Key('acknowledged-${consent.type.wireName}')
            : null,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (consent.current)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      consent.type == ConsentType.terms
                          ? AppStrings.of(context)
                                .messages
                                .consentControlTermsAccepted
                          : AppStrings.of(context)
                                .messages
                                .consentControlPrivacyNoticeRead,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            CheckboxListTile(
              key: key,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.consentLabel(consent.type)),
              subtitle: renewal
                  ? Text(
                      AppStrings.of(context)
                          .messages
                          .consentControlRenewalNeeded,
                    )
                  : null,
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (next) => onChanged(next ?? false),
            ),
          document,
        ],
      );
    }
    if (MediaQuery.textScalerOf(context).scale(16) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: title),
          if (renewal)
            Text(AppStrings.of(context).messages.consentControlRenewalNeeded),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(strings.consentLabel(consent.type)),
          ),
          Row(
            children: [
              Expanded(child: document),
              Semantics(
                label: strings.consentLabel(consent.type),
                child: Switch(key: key, value: value, onChanged: onChanged),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: title,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.consentLabel(consent.type)),
              if (renewal)
                Text(
                  AppStrings.of(context).messages.consentControlRenewalNeeded,
                ),
            ],
          ),
          value: value,
          onChanged: onChanged,
        ),
        document,
      ],
    );
  }
}
