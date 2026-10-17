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
import '../features/privacy/presentation/privacy_strings.dart';
import '../core/widgets/status_view.dart';
import '../core/widgets/editorial_card.dart';
import 'theme.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/presentation/push_scope.dart';
import '../features/matches/application/matches_controller.dart';
import '../features/matches/data/matches_repository.dart';
import '../features/matches/presentation/matches_page.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/presentation/billing_scope.dart';
import '../features/billing/presentation/subscription_page.dart';

class HistaeApp extends StatefulWidget {
  const HistaeApp({
    super.key,
    this.catalogRepository,
    this.sessionController,
    this.pushController,
    this.billingController,
  });
  // Ownership is transferred to the app; requests close when it is disposed.
  final CatalogRepository? catalogRepository;
  final SessionController? sessionController;
  final PushController? pushController;
  final BillingController? billingController;

  @override
  State<HistaeApp> createState() => _HistaeAppState();
}

class _HistaeAppState extends State<HistaeApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  bool _hadSession = false;
  int _resourceRevision = 0;
  SessionPhase? _previousPhase;
  bool _openingPush = false;
  bool _replacingPush = false;
  MaterialPageRoute<void>? _pushRoute;
  MatchesController? _pushMatches;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionController?.addListener(_sessionChanged);
    widget.pushController?.addListener(_pushChanged);
    if (widget.pushController case final push?) unawaited(push.start());
    if (widget.sessionController case final session?) {
      unawaited(session.start());
    }
  }

  void _pushChanged() {
    if (widget.pushController?.pendingOpen == null ||
        widget.sessionController?.phase != SessionPhase.ready) {
      return;
    }
    if (_openingPush) {
      final route = _pushRoute;
      if (route != null && !_replacingPush) {
        _replacingPush = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _pushRoute != route) return;
          final navigator = _navigator.currentState;
          // Only this notification flow is closed. Main-flow forms remain
          // intact, and its chat drafts stay in the shared scoped controller.
          navigator?.popUntil((r) => r == route || r.isFirst);
          if (route.isCurrent) navigator?.pop();
        });
      }
      return;
    }
    _openingPush = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_openPush());
      } else {
        _openingPush = false;
      }
    });
  }

  Future<void> _openPush() async {
    final push = widget.pushController!, session = widget.sessionController!;
    var navigated = false;
    try {
      final intent = await push.authorizeOpen();
      if (!mounted || intent == null || session.phase != SessionPhase.ready) {
        return;
      }
      push.coverMainFlow(true);
      if (intent.matchId != null) {
        final matches = _pushMatches ??= MatchesController(
          MatchesRepository(session),
        );
        _pushRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/notification/match'),
          builder: (_) => MatchesPage(
            controller: matches,
            initialMatchId: intent.matchId,
            notificationFlow: true,
          ),
        );
      } else {
        // A notification only opens an authenticated server re-read.
        _pushRoute = MaterialPageRoute<void>(
          builder: (_) => widget.billingController == null
              ? CatalogPage(repository: widget.catalogRepository)
              : SubscriptionPage(
                  controller: widget.billingController!,
                  catalog: widget.catalogRepository,
                  notificationFlow: true,
                ),
        );
      }
      final route = _pushRoute!;
      navigated = true;
      await _navigator.currentState?.push(route);
      await route.completed;
    } catch (_) {
      /* No raw provider payload or navigation error is logged. */
    } finally {
      _pushMatches?.suspend();
      _pushRoute = null;
      _replacingPush = false;
      if (mounted) {
        push.coverMainFlow(false);
      }
      _openingPush = false;
      if (navigated && mounted) _pushChanged();
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
    final push = widget.pushController;
    if (state == AppLifecycleState.resumed) {
      if (push != null) unawaited(push.resume());
    } else if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      push?.suspend();
    }
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
    widget.pushController?.removeListener(_pushChanged);
    widget.pushController?.dispose();
    widget.billingController?.dispose();
    _pushMatches?.dispose();
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
    themeMode: ThemeMode.dark,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => BillingScope(
      controller: widget.billingController,
      child: PushScope(
        controller: widget.pushController,
        child: widget.pushController == null
            ? child!
            : ListenableBuilder(
                listenable: widget.pushController!,
                builder: (context, _) => Column(
                  children: [
                    if (widget.pushController!.foreground != null &&
                        widget.pushController!.active)
                      Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Une mise à jour Histae est disponible.',
                                ),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    TextButton(
                                      onPressed:
                                          widget.pushController!.openForeground,
                                      child: const Text('Consulter'),
                                    ),
                                    TextButton(
                                      onPressed: widget.pushController!.dismiss,
                                      child: const Text('Plus tard'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(child: child!),
                  ],
                ),
              ),
      ),
    ),
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
