import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_models.dart';
import 'privacy_strings.dart';

/// Presentation of the draft; the controller owns its session-scoped contents
/// and the immutable payload of an uncertain submission.
class PrivacyRequestForm extends StatefulWidget {
  const PrivacyRequestForm({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final PrivacyController controller;
  final bool enabled;

  @override
  State<PrivacyRequestForm> createState() => _PrivacyRequestFormState();
}

class _PrivacyRequestFormState extends State<PrivacyRequestForm> {
  final _form = GlobalKey<FormState>();

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final c = widget.controller;
    final key = c.session.resourceKey;
    final intent =
        c.pendingRequest ?? RightsRequestIntent(c.draftRight, c.draftDetails);
    final strings = AppStrings.of(context);
    final confirmed = await confirmAction(
      context,
      strings.messages.privacyDetailPageSubmitThisRequest,
      [
        rightDescription(strings, intent.type),
        if (intent.details case final details? when details.isNotEmpty)
          '${strings.messages.privacyRequestYourMessage}\n$details',
        strings.messages.privacyDetailPageThisRequestWillBeRecordedFor(
          rightLabel(strings, intent.type),
        ),
      ].join('\n\n'),
      action: strings.messages.privacyDetailPageSubmit,
    );
    if (confirmed && mounted && c.session.resourceKey == key) {
      await c.request(intent.type, details: intent.details);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final strings = AppStrings.of(context);
    final pending = c.pendingRequest;
    final type = pending?.type ?? c.draftRight;
    final details = pending?.details ?? c.draftDetails;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rightLabel(strings, type),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              strings.messages.privacyRightExplanationTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 16),
            children: [Text(rightDescription(strings, type))],
          ),
          const SizedBox(height: 12),
          if (type.requiresDetails || pending?.details != null) ...[
            TextFormField(
              key: ValueKey((
                c.session.resourceKey,
                c.requestDraftRevision,
                pending != null,
              )),
              initialValue: details,
              enabled: widget.enabled,
              readOnly: pending != null,
              minLines: 3,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: strings.messages.privacyRequestDetailsLabel,
                helperText: rightDetailsPrompt(strings, type),
                helperMaxLines: 5,
                counterText:
                    '${details.runes.length} / ${RightsRequestIntent.maxDetailsLength}',
              ),
              validator: (value) => RightsRequestIntent(type, value).valid
                  ? null
                  : strings.messages.privacyRequestDetailsInvalid,
              onChanged: (value) => c.editRightDraft(details: value),
            ),
            const SizedBox(height: 24),
          ],
          if (pending != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                strings
                    .messages
                    .privacyDetailPageTheResponseStillNeedsConfirmationRefresh,
              ),
            ),
          HistaeButton(
            onPressed: widget.enabled ? _submit : null,
            child: Text(
              pending == null
                  ? strings.messages.privacyDetailPageSubmitMyRequest
                  : strings.messages.privacyDetailPageResumeThisRequest,
            ),
          ),
        ],
      ),
    );
  }
}
