import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/session_controller.dart';
import 'otp_form.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key, required this.session, this.registration = false});
  final SessionController session;
  final bool registration;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return HistaeScaffold(
      appBar: AppBar(
        title: Text(registration ? strings.createAccount : strings.signIn),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: OtpForm(session: session, registration: registration),
          ),
        ),
      ),
    );
  }
}
