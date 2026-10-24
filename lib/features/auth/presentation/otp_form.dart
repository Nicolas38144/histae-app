import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/otp_controller.dart';
import '../application/session_controller.dart';
import '../domain/auth_models.dart';

/// Shared phone verification form. Its caller owns what happens after login.
class OtpForm extends StatefulWidget {
  const OtpForm({
    super.key,
    required this.session,
    this.registration = false,
    this.onAuthenticated,
  });
  final SessionController session;
  final bool registration;
  final Future<void> Function(TokenPair tokens)? onAuthenticated;

  @override
  State<OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<OtpForm> {
  late final _controller = OtpController(
    widget.session,
    onAuthenticated: widget.onAuthenticated,
  );
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _phone.clear();
    _phone.dispose();
    _otp.clear();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controller = _controller;
        final enabled = !controller.busy && controller.retrySeconds == 0;
        return AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              EditorialCard(
                title: widget.registration
                    ? strings.messages.registrationPhoneTitle
                    : strings.loginHeading,
                body: widget.registration
                    ? strings.messages.registrationPhoneIntro
                    : strings.otpIntroduction,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                key: const Key('phone'),
                enabled: !controller.busy && !controller.canResume,
                decoration: InputDecoration(
                  labelText: strings.phoneLabel,
                  hintText: strings.phoneHint,
                  helperText: strings.phoneHelp,
                  helperMaxLines: 3,
                ),
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              if (controller.notice == 'otp_accepted')
                Semantics(liveRegion: true, child: Text(strings.otpAccepted)),
              if (controller.failure case final failure?) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(strings.authFailure(failure)),
                ),
                const SizedBox(height: 16),
              ],
              if (controller.verificationUncertain)
                Text(strings.verificationUncertain),
              if (controller.requested &&
                  !controller.verificationUncertain) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _otp,
                  key: const Key('otp'),
                  enabled: !controller.busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: strings.otpLabel),
                ),
                HistaeButton(
                  onPressed: enabled
                      ? () async {
                          final code = _otp.text;
                          _otp.clear();
                          await controller.verify(code);
                        }
                      : null,
                  child: Text(strings.verifyOtp),
                ),
                const SizedBox(height: 16),
              ],
              if (controller.retrySeconds > 0)
                Text(strings.retryIn(controller.retrySeconds)),
              if (!controller.canResume)
                HistaeButton(
                  onPressed: enabled
                      ? () {
                          _otp.clear();
                          controller.send(_phone.text);
                        }
                      : null,
                  child: Text(strings.sendOtp),
                )
              else
                OutlinedButton(
                  onPressed: enabled
                      ? () {
                          _otp.clear();
                          controller.send(_phone.text);
                        }
                      : null,
                  child: Text(strings.resendOtp),
                ),
              if (controller.canResume && controller.failure != null)
                OutlinedButton(
                  onPressed: enabled
                      ? () => controller.send(_phone.text, newIntention: false)
                      : null,
                  child: Text(strings.resumeOtp),
                ),
              if (controller.canResume)
                TextButton(
                  onPressed: controller.busy
                      ? null
                      : () {
                          _otp.clear();
                          controller.changePhone();
                        },
                  child: Text(strings.changePhone),
                ),
              if (controller.busy) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  semanticsLabel: strings.actionInProgress,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
