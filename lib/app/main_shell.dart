import 'package:flutter/material.dart';

import '../core/widgets/histae_scaffold.dart';
import '../features/auth/domain/authenticated_session.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/discovery/application/discovery_controller.dart';
import '../features/discovery/application/discovery_visibility_controller.dart';
import '../features/discovery/data/device_location.dart';
import '../features/discovery/presentation/discovery_page.dart';
import '../features/matches/application/matches_controller.dart';
import '../features/matches/presentation/matches_page.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/presentation/push_scope.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/presentation/profile_page.dart';
import 'main_navigation_bar.dart';
import 'session_repositories.dart';

/// Keeps the three main views and their data alive for the current session.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.session,
    this.catalog,
    this.repositories,
  });
  final AuthenticatedSession session;
  final CatalogRepository? catalog;
  final SessionRepositories? repositories;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final _repositories =
      widget.repositories ?? SessionRepositories(widget.session);
  late final _visibility = DiscoveryVisibilityController(widget.session);
  late final _profile = ProfileController(_repositories.profile);
  late final _discovery = DiscoveryController(
    _repositories.discovery,
    DeviceLocation(),
  );
  late final _matches = MatchesController(
    _repositories.matches,
    realtime: _repositories.realtime.channel(),
    onRemoved: _discovery.forgetEncounter,
  );
  final _pageStorage = PageStorageBucket();
  PushController? _push;
  bool _covered = false;
  int _selected = 0;
  String? _initialMatchId;
  bool? _lastPaused;

  @override
  void initState() {
    super.initState();
    _visibility.addListener(_visibilityChanged);
  }

  void _visibilityChanged() {
    final paused = _visibility.paused;
    if (paused == _lastPaused) return;
    final initial = _lastPaused == null;
    _lastPaused = paused;
    if (paused == null || initial) return;
    _discovery.deactivate();
    if (!_covered) {
      Future.microtask(_discovery.activate);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PushScope.maybeOf(context);
    if (next == _push) return;
    _push?.removeListener(_pushRouteChanged);
    _push = next;
    _push?.addListener(_pushRouteChanged);
    _covered = _push?.coversMainFlow == true;
    _matches.setRealtimeEnabled(!_covered);
  }

  void _pushRouteChanged() {
    final covered = _push?.coversMainFlow == true;
    if (covered == _covered) return;
    _matches.setRealtimeEnabled(!covered);
    setState(() => _covered = covered);
  }

  void _select(int index) {
    if (_selected == index) return;
    setState(() {
      _selected = index;
      _initialMatchId = null;
    });
  }

  Future<void> _openMatches([String? id]) async {
    if (!mounted || widget.session.phase != SessionPhase.ready) return;
    if (id == null) {
      _select(1);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _selected = 1;
      _initialMatchId = id;
    });
  }

  @override
  void dispose() {
    _push?.removeListener(_pushRouteChanged);
    _matches.dispose();
    _discovery.dispose();
    _visibility.dispose();
    _profile.dispose();
    if (widget.repositories == null) _repositories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    extendBody: true,
    body: PageStorage(
      bucket: _pageStorage,
      child: Offstage(
        offstage: _covered,
        child: IndexedStack(
          index: _selected,
          children: [
            DiscoveryPage(
              key: const PageStorageKey('main-discovery'),
              controller: _discovery,
              profile: _profile,
              visibility: _visibility,
              openMatches: _openMatches,
            ),
            MatchesPage(
              key: const PageStorageKey('main-matches'),
              controller: _matches,
              initialMatchId: _initialMatchId,
              onInitialMatchHandled: () => _initialMatchId = null,
            ),
            ProfilePage(
              key: const PageStorageKey('main-profile'),
              controller: _profile,
              privacyRepository: _repositories.privacy,
              deviceRepository: _repositories.devices,
              continuation: _matches.continuation,
              catalog: widget.catalog,
              visibility: _visibility,
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: MainNavigationBar(
      selectedIndex: _selected,
      onSelected: _select,
    ),
  );
}
