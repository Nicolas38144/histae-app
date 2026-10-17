import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/widgets/status_view.dart';
import '../features/auth/application/session_controller.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/consents/presentation/consents_page.dart';
import '../features/privacy/presentation/privacy_strings.dart';
import '../features/profile/presentation/profile_page.dart';
import 'welcome_page.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.session, this.catalog});
  final SessionController session;
  final CatalogRepository? catalog;
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    switch (session.phase) {
      case SessionPhase.signedOut:
        return WelcomePage(repository: catalog, session: session);
      case SessionPhase.needsConsents:
        return ConsentsPage(session: session, onboarding: true);
      case SessionPhase.ready:
        return ProfilePage(session: session, catalog: catalog);
      case SessionPhase.restoring:
      case SessionPhase.synchronizing:
        return Scaffold(
          appBar: AppBar(title: Text(strings.appName)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                LinearProgressIndicator(semanticsLabel: strings.sessionLoading),
                const SizedBox(height: 24),
                Text(strings.sessionLoading),
                if (session.hasSession)
                  TextButton(
                    onPressed: session.logout,
                    child: Text(strings.logout),
                  ),
              ],
            ),
          ),
        );
      case SessionPhase.unavailable:
      case SessionPhase.storageFailure:
        return Scaffold(
          appBar: AppBar(title: Text(strings.appName)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                StatusView(
                  title: strings.sessionUnavailable,
                  message: strings.authFailure(session.failure!),
                  action: OutlinedButton(
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
                if (session.notice != null) Text(sessionNotice(session.notice)),
                if (session.hasSession)
                  TextButton(
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
