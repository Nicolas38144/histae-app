import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/generated/app_messages.dart';
import '../core/l10n/locale_controller.dart';
import '../core/widgets/app_privacy_shield.dart';
import '../features/auth/application/session_controller.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/presentation/billing_scope.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/continuation/data/rewarded_video_gateway.dart';
import '../features/continuation/presentation/rewarded_video_scope.dart';
import '../features/help/application/help_controller.dart';
import '../features/help/presentation/help_scope.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/presentation/push_scope.dart';
import 'account_language_binding.dart';
import 'app_opening.dart';
import 'notification_navigation.dart';
import 'notification_overlay.dart';
import 'session_gate.dart';
import 'session_repositories.dart';
import 'theme.dart';
import 'welcome_page.dart';

class HistaeApp extends StatefulWidget {
  const HistaeApp({
    super.key,
    this.catalogRepository,
    this.localeController,
    this.sessionController,
    this.pushController,
    this.billingController,
    this.rewardedVideoGateway,
    this.repositories,
    this.helpController,
  });
  // Ownership is transferred to the app; requests close when it is disposed.
  final CatalogRepository? catalogRepository;
  final LocaleController? localeController;
  final SessionController? sessionController;
  final PushController? pushController;
  final BillingController? billingController;
  final RewardedVideoGateway? rewardedVideoGateway;
  final SessionRepositories? repositories;
  final HelpController? helpController;

  @override
  State<HistaeApp> createState() => _HistaeAppState();
}

class _HistaeAppState extends State<HistaeApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late final _locale = widget.localeController ?? LocaleController();
  AccountLanguageBinding? _accountLanguage;
  bool _hadSession = false;
  int _resourceRevision = 0;
  SessionPhase? _previousPhase;
  late final NotificationNavigation _notifications;
  SessionRepositories? _repositories;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.helpController?.load());
    widget.sessionController?.addListener(_sessionChanged);
    if (widget.sessionController case final session?) {
      _repositories =
          widget.repositories ??
          SessionRepositories(
            session,
            devices: widget.pushController?.repository,
          );
    }
    _notifications = NotificationNavigation(
      navigator: _navigator,
      repositories: _repositories,
      pushController: widget.pushController,
      sessionController: widget.sessionController,
      catalogRepository: widget.catalogRepository,
      billingController: widget.billingController,
      isMounted: () => mounted,
    );
    if (widget.sessionController case final session?) {
      _accountLanguage = AccountLanguageBinding(_locale, session);
    }
    if (widget.pushController case final push?) unawaited(push.start());
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
  void didChangeLocales(List<Locale>? locales) => _locale.systemLocaleChanged();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_repositories?.drafts.flush());
    }
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sessionController?.removeListener(_sessionChanged);
    _notifications.dispose();
    _accountLanguage?.dispose();
    widget.pushController?.dispose();
    widget.billingController?.dispose();
    _repositories?.dispose();
    widget.sessionController?.dispose();
    widget.catalogRepository?.close();
    _locale.dispose();
    widget.helpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
    controller: _locale,
    child: ListenableBuilder(
      listenable: _locale,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigator,
        onGenerateTitle: (context) => AppStrings.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: histaeTheme(Brightness.light),
        darkTheme: histaeTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        locale: _locale.locale,
        supportedLocales: AppMessages.supportedLocales,
        localeResolutionCallback: LocaleController.resolve,
        localizationsDelegates: AppMessages.localizationsDelegates,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).appBarTheme.systemOverlayStyle!,
          child: AppPrivacyShield(
            child: AppOpening(
              child: RewardedVideoScope(
                gateway: widget.rewardedVideoGateway,
                child: BillingScope(
                  controller: widget.billingController,
                  child: PushScope(
                    controller: widget.pushController,
                    child: HelpScope(
                      controller: widget.helpController,
                      child: NotificationOverlay(
                        controller: widget.pushController,
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        home: widget.sessionController == null
            ? WelcomePage(repository: widget.catalogRepository)
            : ListenableBuilder(
                listenable: widget.sessionController!,
                builder: (context, _) => SessionGate(
                  session: widget.sessionController!,
                  catalog: widget.catalogRepository,
                  repositories: _repositories,
                ),
              ),
      ),
    ),
  );
}
