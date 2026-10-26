import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/widgets/histae_button.dart';
import '../core/widgets/histae_scaffold.dart';
import '../core/widgets/status_view.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/consents/presentation/consents_page.dart';
import '../features/privacy/presentation/privacy_strings.dart';
import '../features/registration/application/registration_controller.dart';
import '../features/registration/presentation/registration_page.dart';
import 'main_shell.dart';
import 'session_repositories.dart';
import 'welcome_page.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.session,
    this.catalog,
    this.repositories,
  });
  final SessionController session;
  final CatalogRepository? catalog;
  final SessionRepositories? repositories;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  RegistrationController? _registration;
  SessionController get session => widget.session;
  CatalogRepository? get catalog => widget.catalog;
  SessionRepositories? get repositories => widget.repositories;

  void _register() => setState(() {
    _registration = RegistrationController(session);
  });

  void _endRegistration() {
    final previous = _registration;
    setState(() {
      _registration = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  @override
  void dispose() {
    _registration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_registration case final registration?) {
      return RegistrationPage(
        controller: registration,
        onComplete: _endRegistration,
        onCancel: _endRegistration,
        onSignIn: () {
          _endRegistration();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => OtpPage(session: session)),
          );
        },
      );
    }
    switch (session.phase) {
      case SessionPhase.signedOut:
        return WelcomePage(
          repository: catalog,
          session: session,
          onRegister: _register,
        );
      case SessionPhase.needsConsents:
        return ConsentsPage(session: session, onboarding: true);
      case SessionPhase.ready:
        return MainShell(
          key: ValueKey(session.resourceKey),
          session: session,
          catalog: catalog,
          repositories: repositories,
        );
      case SessionPhase.restoring:
      case SessionPhase.synchronizing:
        return HistaeScaffold(
          appBar: AppBar(title: Text(strings.appName)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                LinearProgressIndicator(semanticsLabel: strings.sessionLoading),
                const SizedBox(height: 24),
                Text(strings.sessionLoading),
                if (session.hasSession)
                  HistaeButton.text(
                    onPressed: session.logout,
                    child: Text(strings.logout),
                  ),
              ],
            ),
          ),
        );
      case SessionPhase.unavailable:
      case SessionPhase.storageFailure:
        return HistaeScaffold(
          appBar: AppBar(title: Text(strings.appName)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                StatusView(
                  title: strings.sessionUnavailable,
                  message: strings.authFailure(session.failure!),
                  action: HistaeButton.outlined(
                    onPressed: session.retrySeconds > 0
                        ? null
                        : (session.hasSession
                              ? session.synchronize
                              : session.logout),
                    child: Text(
                      session.retrySeconds > 0
                          ? strings.retryIn(session.retrySeconds)
                          : strings.retry,
                    ),
                  ),
                ),
                if (session.notice != null)
                  Text(sessionNotice(AppStrings.of(context), session.notice)),
                if (session.hasSession)
                  HistaeButton.text(
                    onPressed: session.logout,
                    child: Text(strings.logout),
                  ),
              ],
            ),
          ),
        );
    }
  }
}
