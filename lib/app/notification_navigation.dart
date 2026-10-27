import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/application/session_controller.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/presentation/subscription_page.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/matches/application/matches_controller.dart';
import '../features/matches/data/matches_repository.dart';
import '../features/matches/presentation/matches_page.dart';
import '../features/notifications/application/push_controller.dart';
import 'session_repositories.dart';

/// Owns only the temporary notification route and its scoped chat state.
/// Session reset navigation remains the responsibility of HistaeApp.
class NotificationNavigation {
  NotificationNavigation({
    required this._navigator,
    required this.pushController,
    required this.sessionController,
    required this.catalogRepository,
    required this.billingController,
    required this.isMounted,
    this.repositories,
  }) {
    pushController?.addListener(_pushChanged);
  }
  final GlobalKey<NavigatorState> _navigator;
  final PushController? pushController;
  final SessionController? sessionController;
  final CatalogRepository? catalogRepository;
  final BillingController? billingController;
  final bool Function() isMounted;
  final SessionRepositories? repositories;
  bool _disposed = false;

  bool get mounted => !_disposed && isMounted();
  bool _openingPush = false, _replacingPush = false;
  MaterialPageRoute<void>? _pushRoute;
  MatchesController? _pushMatches;

  void _pushChanged() {
    if (pushController?.pendingOpen == null ||
        sessionController?.phase != SessionPhase.ready) {
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
    final push = pushController!, session = sessionController!;
    var navigated = false;
    try {
      final intent = await push.authorizeOpen();
      if (!mounted || intent == null || session.phase != SessionPhase.ready) {
        return;
      }
      push.coverMainFlow(true);
      if (intent.matchId != null) {
        final matches = _pushMatches ??= MatchesController(
          repositories?.matches ?? MatchesRepository(session),
          realtime: repositories?.realtime.channel(),
        );
        _pushRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/notification/match'),
          builder: (_) => MatchesPage(
            controller: matches,
            catalog: catalogRepository,
            initialMatchId: intent.matchId,
            notificationFlow: true,
          ),
        );
      } else {
        // A notification only opens an authenticated server re-read.
        _pushRoute = MaterialPageRoute<void>(
          builder: (_) => billingController == null
              ? CatalogPage(repository: catalogRepository)
              : SubscriptionPage(
                  controller: billingController!,
                  catalog: catalogRepository,
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

  void dispose() {
    _disposed = true;
    pushController?.removeListener(_pushChanged);
    _pushMatches?.dispose();
  }
}
