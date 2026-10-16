import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/l10n/app_strings.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/consents/presentation/consents_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../core/widgets/status_view.dart';
import '../core/widgets/editorial_card.dart';
import 'theme.dart';

class HistaeApp extends StatefulWidget {
  const HistaeApp({super.key, this.catalogRepository, this.sessionController});
  // Ownership is transferred to the app; requests close when it is disposed.
  final CatalogRepository? catalogRepository;
  final SessionController? sessionController;

  @override
  State<HistaeApp> createState() => _HistaeAppState();
}

class _HistaeAppState extends State<HistaeApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  bool _hadSession = false;
  int _resourceRevision = 0;
  SessionPhase? _previousPhase;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionController?.addListener(_sessionChanged);
    if (widget.sessionController case final session?) {
      unawaited(session.start());
    }
  }

  void _sessionChanged() {
    final session = widget.sessionController!;
    final reset =
        _hadSession != session.hasSession ||
        _resourceRevision != session.resourceRevision ||
        (_previousPhase == SessionPhase.ready &&
            session.phase != SessionPhase.ready) ||
        session.phase == SessionPhase.signedOut ||
        session.phase == SessionPhase.storageFailure;
    _hadSession = session.hasSession;
    _resourceRevision = session.resourceRevision;
    _previousPhase = session.phase;
    if (reset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigator.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = widget.sessionController;
    if (state == AppLifecycleState.resumed &&
        session != null &&
        !session.isSaving &&
        (session.phase == SessionPhase.ready ||
            session.phase == SessionPhase.needsConsents ||
            session.phase == SessionPhase.unavailable)) {
      unawaited(session.synchronize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sessionController?.removeListener(_sessionChanged);
    widget.sessionController?.dispose();
    widget.catalogRepository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: const AppStrings().appName,
    debugShowCheckedModeBanner: false,
    theme: histaeTheme(Brightness.light),
    darkTheme: histaeTheme(Brightness.dark),
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: widget.sessionController == null
        ? _WelcomePage(repository: widget.catalogRepository)
        : ListenableBuilder(
            listenable: widget.sessionController!,
            builder: (context, _) =>
                _sessionHome(context, widget.sessionController!),
          ),
  );

  Widget _sessionHome(BuildContext context, SessionController session) {
    final strings = AppStrings.of(context);
    switch (session.phase) {
      case SessionPhase.signedOut:
        return _WelcomePage(
          repository: widget.catalogRepository,
          session: session,
        );
      case SessionPhase.needsConsents:
        return ConsentsPage(session: session, onboarding: true);
      case SessionPhase.ready:
        return ProfilePage(session: session, catalog: widget.catalogRepository);
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

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.repository, this.session});
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
                      child: Text(
                        auth.notice == 'logout_confirmed'
                            ? strings.logoutConfirmed
                            : strings.logoutUnconfirmed,
                      ),
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
