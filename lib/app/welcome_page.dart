import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/language_picker.dart';
import '../core/widgets/connection_artwork.dart';
import '../core/widgets/histae_button.dart';
import '../core/widgets/histae_scaffold.dart';
import '../core/widgets/histae_wordmark.dart';
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
    return HistaeScaffold(
      appBar: AppBar(
        title: const HistaeWordmark(),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context).messages.welcomePageAnotherWayToMeet,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    strings.welcomeTitle,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  strings.welcomeBody,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                if (session case final auth?) ...[
                  if (auth.notice != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        sessionNotice(AppStrings.of(context), auth.notice),
                      ),
                    ),
                  if (auth.failure case final failure?)
                    Text(strings.authFailure(failure)),
                  HistaeButton(
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
                const SizedBox(height: 28),
                const ConnectionArtwork(),
                const SizedBox(height: 20),
                Text(
                  AppStrings.of(context)
                      .messages
                      .welcomePageTimeReciprocityConsent,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
