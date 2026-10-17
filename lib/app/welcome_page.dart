import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/widgets/editorial_card.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/privacy/presentation/privacy_strings.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.repository, this.session});
  final CatalogRepository? repository;
  final SessionController? session;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                EditorialCard(
                  title: strings.welcomeTitle,
                  body: strings.welcomeBody,
                  eyebrow: strings.wordsFirst,
                ),
                const SizedBox(height: 24),
                if (session case final auth?) ...[
                  if (auth.notice != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(sessionNotice(auth.notice)),
                    ),
                  if (auth.failure case final failure?)
                    Text(strings.authFailure(failure)),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            OtpPage(session: auth, registration: true),
                      ),
                    ),
                    child: Text(strings.createAccount),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OtpPage(session: auth),
                      ),
                    ),
                    child: Text(strings.existingAccount),
                  ),
                  const SizedBox(height: 16),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/catalog'),
                      builder: (_) => CatalogPage(repository: repository),
                    ),
                  ),
                  child: Text(strings.catalogAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
