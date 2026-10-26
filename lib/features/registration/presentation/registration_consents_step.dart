import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../consents/data/legal_document_opener.dart';
import '../../consents/domain/consent_state.dart';
import '../../consents/presentation/consent_control.dart';
import '../application/registration_controller.dart';

class RegistrationConsentsStep extends StatefulWidget {
  const RegistrationConsentsStep({
    super.key,
    required this.controller,
    required this.onContinue,
  });
  final RegistrationController controller;
  final VoidCallback onContinue;

  @override
  State<RegistrationConsentsStep> createState() =>
      _RegistrationConsentsStepState();
}

class _RegistrationConsentsStepState extends State<RegistrationConsentsStep> {
  bool _openFailed = false;

  Future<void> _open(PublicConsent consent) async {
    final opened = await openLegalDocument(Uri.parse(consent.documentUrl));
    if (mounted) setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final strings = AppStrings.of(context);
    return ListView(
      key: const PageStorageKey('registration-consents'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(strings.consentsIntro),
        const SizedBox(height: 16),
        Text(strings.messages.registrationConsentIntro),
        const SizedBox(height: 16),
        if (controller.loadingDocuments)
          LinearProgressIndicator(semanticsLabel: strings.actionInProgress),
        if (controller.failure case final failure?) ...[
          Semantics(
            liveRegion: true,
            child: Text(strings.authFailure(failure)),
          ),
          const SizedBox(height: 12),
          HistaeButton.outlined(
            onPressed:
                controller.loadingDocuments || controller.retrySeconds > 0
                ? null
                : controller.loadDocuments,
            child: Text(
              controller.retrySeconds > 0
                  ? strings.retryIn(controller.retrySeconds)
                  : strings.retry,
            ),
          ),
        ],
        if (_openFailed) Text(strings.openDocumentError),
        for (final consent in controller.documents)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConsentControl(
                consent: consent,
                value: controller.choice(consent.type),
                onChanged: controller.loadingDocuments || controller.saving
                    ? null
                    : (value) => controller.setChoice(consent.type, value),
                onOpen: () => _open(consent),
              ),
            ),
          ),
        const SizedBox(height: 24),
        HistaeButton(
          key: const Key('registration-next'),
          onPressed:
              !controller.loadingDocuments &&
                  !controller.saving &&
                  controller.canVerify
              ? widget.onContinue
              : null,
          child: Text(strings.messages.registrationContinue),
        ),
      ],
    );
  }
}
