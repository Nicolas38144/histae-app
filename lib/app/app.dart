import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/l10n/app_strings.dart';
import '../features/auth/application/session_controller.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/presentation/billing_scope.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/presentation/push_scope.dart';
import 'app_opening.dart';
import 'notification_navigation.dart';
import 'notification_overlay.dart';
import 'session_gate.dart';
import 'theme.dart';
import 'welcome_page.dart';

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
  late final NotificationNavigation _notifications;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionController?.addListener(_sessionChanged);
    _notifications = NotificationNavigation(
      navigator: _navigator,
      pushController: widget.pushController,
      sessionController: widget.sessionController,
      catalogRepository: widget.catalogRepository,
      billingController: widget.billingController,
      isMounted: () => mounted,
    );
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
    _notifications.dispose();
    widget.pushController?.dispose();
    widget.billingController?.dispose();
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
    builder: (context, child) => AppOpening(
      child: BillingScope(
        controller: widget.billingController,
        child: PushScope(
          controller: widget.pushController,
          child: NotificationOverlay(
            controller: widget.pushController,
            child: child!,
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
            ),
          ),
  );
}
