import 'dart:async';

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
import 'main_tab_pager.dart';
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
  final _pages = PageController(initialPage: MainTab.discovery.index);
  PushController? _push;
  bool _covered = false;
  MainTab _selected = MainTab.discovery;
  String? _initialMatchId;
  bool? _lastPaused;
  int _lastPhotoRevision = 0;

  @override
  void initState() {
    super.initState();
    _visibility.addListener(_visibilityChanged);
    _profile.addListener(_profilePhotoChanged);
  }

  void _profilePhotoChanged() {
    if (_profile.photoRevision == _lastPhotoRevision) return;
    _lastPhotoRevision = _profile.photoRevision;
    _matches.profilePhotoChanged();
    _discovery.deactivate();
    if (!_covered) Future.microtask(_discovery.activate);
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
    _initialMatchId = null;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      unawaited(
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  void _pageChanged(int index) {
    final tab = MainTab.values[index];
    if (_selected == tab) return;
    setState(() {
      _selected = tab;
    });
  }

  Future<void> _openMatches([String? id]) async {
    if (!mounted || widget.session.phase != SessionPhase.ready) return;
    if (id == null) {
      _select(MainTab.matches.index);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _initialMatchId = id;
    });
    _pages.jumpToPage(MainTab.matches.index);
  }

  @override
  void dispose() {
    _push?.removeListener(_pushRouteChanged);
    _pages.dispose();
    _matches.dispose();
    _discovery.dispose();
    _visibility.dispose();
    _profile.removeListener(_profilePhotoChanged);
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
        child: TickerMode(
          enabled: !_covered,
          child: MainTabPager(
            controller: _pages,
            selectedIndex: _selected.index,
            onPageChanged: _pageChanged,
            children: [
              for (final tab in MainTab.values)
                switch (tab) {
                  MainTab.discovery => DiscoveryPage(
                    key: const PageStorageKey('main-discovery'),
                    controller: _discovery,
                    profile: _profile,
                    visibility: _visibility,
                    visible: _selected == MainTab.discovery && !_covered,
                    openMatches: _openMatches,
                  ),
                  MainTab.matches => MatchesPage(
                    key: const PageStorageKey('main-matches'),
                    controller: _matches,
                    initialMatchId: _initialMatchId,
                    onInitialMatchHandled: () => _initialMatchId = null,
                  ),
                  MainTab.profile => ProfilePage(
                    key: const PageStorageKey('main-profile'),
                    controller: _profile,
                    privacyRepository: _repositories.privacy,
                    deviceRepository: _repositories.devices,
                    continuation: _matches.continuation,
                    catalog: widget.catalog,
                    visibility: _visibility,
                  ),
                },
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: MainNavigationBar(
      selectedIndex: _selected.index,
      onSelected: _select,
    ),
  );
}
