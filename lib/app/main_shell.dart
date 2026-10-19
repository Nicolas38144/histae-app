import 'package:flutter/material.dart';

import '../core/widgets/histae_scaffold.dart';

import '../features/auth/domain/authenticated_session.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/discovery/application/discovery_controller.dart';
import '../features/discovery/data/device_location.dart';
import '../features/discovery/data/discovery_repository.dart';
import '../features/discovery/presentation/discovery_page.dart';
import '../features/matches/application/matches_controller.dart';
import '../features/matches/data/matches_repository.dart';
import '../features/matches/presentation/matches_page.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/presentation/push_scope.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/presentation/profile_page.dart';
import 'main_navigation_bar.dart';

/// Owns the private tabs and their session-scoped controllers. Only the visible
/// tab is mounted, so hidden tabs cannot restart discovery or realtime work.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.session, this.catalog});

  final AuthenticatedSession session;
  final CatalogRepository? catalog;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final _profile = ProfileController(ProfileRepository(widget.session));
  late final _discovery = DiscoveryController(
    DiscoveryRepository(widget.session),
    DeviceLocation(),
  );
  late final _matches = MatchesController(
    MatchesRepository(widget.session),
    onRemoved: _discovery.forgetEncounter,
  );
  final _pageStorage = PageStorageBucket();
  PushController? _push;
  bool _covered = false;
  int _selected = 0, _matchRequest = 0;
  String? _initialMatchId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PushScope.maybeOf(context);
    if (next == _push) return;
    _push?.removeListener(_pushRouteChanged);
    _push = next;
    _push?.addListener(_pushRouteChanged);
    _covered = _push?.coversMainFlow == true;
  }

  void _pushRouteChanged() {
    final covered = _push?.coversMainFlow == true;
    if (covered == _covered) return;
    if (covered) {
      _discovery.deactivate();
      _matches.suspend();
    }
    setState(() => _covered = covered);
  }

  void _select(int index) {
    if (_selected == index) return;
    if (_selected == 0) _discovery.deactivate();
    if (_selected == 1) _matches.suspend();
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
    _discovery.deactivate();
    setState(() {
      _selected = 1;
      _initialMatchId = id;
      _matchRequest++;
    });
  }

  @override
  void dispose() {
    _push?.removeListener(_pushRouteChanged);
    _matches.dispose();
    _discovery.dispose();
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    body: PageStorage(
      bucket: _pageStorage,
      child: _covered
          ? const SizedBox.shrink()
          : switch (_selected) {
              0 => DiscoveryPage(
                key: const PageStorageKey('main-discovery'),
                controller: _discovery,
                profile: _profile,
                openMatches: _openMatches,
              ),
              1 => MatchesPage(
                key: PageStorageKey('main-matches-$_matchRequest'),
                controller: _matches,
                initialMatchId: _initialMatchId,
                onInitialMatchHandled: () => _initialMatchId = null,
              ),
              _ => ProfilePage(
                key: const PageStorageKey('main-profile'),
                controller: _profile,
                continuation: _matches.continuation,
                catalog: widget.catalog,
              ),
            },
    ),
    bottomNavigationBar: MainNavigationBar(
      selectedIndex: _selected,
      onSelected: _select,
    ),
  );
}
