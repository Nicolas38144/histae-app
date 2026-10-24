import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/language_picker.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/otp_form.dart';
import '../application/registration_controller.dart';
import 'registration_consents_step.dart';
import 'registration_preferences_step.dart';
import 'registration_profile_step.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.controller,
    required this.onComplete,
    required this.onCancel,
  });
  final RegistrationController controller;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  Future<void> _back() async {
    final controller = widget.controller;
    if (controller.saving) return;
    if (!controller.verified && controller.step != RegistrationStep.profile) {
      controller.back();
      return;
    }
    final copy = AppStrings.of(context).messages;
    if (await confirmAction(
          context,
          copy.registrationLeaveTitle,
          copy.registrationLeaveBody,
          action: copy.profileEditorLeave,
        ) &&
        mounted) {
      widget.onCancel();
    }
  }

  Future<void> _authenticate(TokenPair tokens) async {
    await widget.controller.authenticate(tokens);
    if (mounted && widget.controller.completed) widget.onComplete();
  }

  Future<void> _retry() async {
    await widget.controller.retrySave();
    if (mounted && widget.controller.completed) widget.onComplete();
  }

  void _continue() {
    widget.controller.next();
    if (widget.controller.step == RegistrationStep.phone &&
        widget.controller.verified) {
      _retry();
    }
  }

  Widget _phone() {
    final controller = widget.controller;
    if (controller.step != RegistrationStep.phone) {
      return const SizedBox.shrink();
    }
    final strings = AppStrings.of(context);
    if (!controller.saving && !controller.verified) {
      return Column(
        children: [
          if (controller.failure case final failure?)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Semantics(
                liveRegion: true,
                child: Text(strings.authFailure(failure)),
              ),
            ),
          Expanded(
            child: OtpForm(
              session: controller.session,
              registration: true,
              onAuthenticated: _authenticate,
            ),
          ),
        ],
      );
    }
    final copy = strings.messages;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          controller.existingAccount
              ? copy.registrationExistingAccount
              : copy.registrationSaving,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        if (controller.saving)
          LinearProgressIndicator(semanticsLabel: strings.actionInProgress),
        if (controller.failure case final failure?) ...[
          Semantics(
            liveRegion: true,
            child: Text(strings.authFailure(failure)),
          ),
          const SizedBox(height: 12),
          Text(copy.registrationRetrySave),
        ],
        const SizedBox(height: 24),
        if (!controller.saving)
          HistaeButton(
            onPressed: controller.retrySeconds > 0
                ? null
                : controller.existingAccount
                ? widget.onComplete
                : _retry,
            child: Text(
              controller.retrySeconds > 0
                  ? strings.retryIn(controller.retrySeconds)
                  : controller.existingAccount
                  ? copy.registrationContinue
                  : strings.retry,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final strings = AppStrings.of(context);
      final copy = strings.messages;
      final labels = [
        copy.registrationProfileStep,
        copy.registrationPreferencesStep,
        copy.registrationConsentsStep,
        copy.registrationPhoneStep,
      ];
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: HistaeScaffold(
          appBar: AppBar(
            title: Text(strings.createAccount),
            leading: IconButton(
              onPressed: controller.saving ? null : _back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [if (!controller.saving) const LanguageButton()],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            copy.registrationStep(
                              controller.step.index + 1,
                              labels[controller.step.index],
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: (controller.step.index + 1) / labels.length,
                            semanticsLabel: labels[controller.step.index],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: controller.step.index,
                        children: [
                          RegistrationProfileStep(
                            draft: controller.draft,
                            onContinue: _continue,
                          ),
                          RegistrationPreferencesStep(
                            draft: controller.draft,
                            onContinue: _continue,
                          ),
                          RegistrationConsentsStep(
                            controller: controller,
                            onContinue: _continue,
                          ),
                          _phone(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
