import '../core/network/read_snapshots.dart';
import '../features/auth/domain/authenticated_session.dart';
import '../features/discovery/data/discovery_repository.dart';
import '../features/drafts/application/draft_controller.dart';
import '../features/drafts/data/draft_vault.dart';
import '../features/matches/data/matches_repository.dart';
import '../features/matches/data/realtime_hub.dart';
import '../features/notifications/data/device_repository.dart';
import '../features/privacy/data/privacy_repository.dart';
import '../features/profile/data/profile_repository.dart';

/// Composition root for private data. Repositories share resource invalidation,
/// while authentication remains responsible only for session authorization.
final class SessionRepositories {
  SessionRepositories(
    this.session, {
    DeviceRepository? devices,
    DraftVault? draftVault,
  }) {
    drafts = DraftController(session, draftVault ?? MemoryDraftVault());
    profile = ProfileRepository(session, cache: _reads);
    matches = MatchesRepository(session, cache: _reads);
    privacy = PrivacyRepository(session, cache: _reads);
    discovery = DiscoveryRepository(session, cache: _reads);
    this.devices = devices ?? DeviceRepository(session, cache: _reads);
    realtime = RealtimeHub(session);
    _key = _currentKey;
    session.addListener(_changed);
  }

  final AuthenticatedSession session;
  final _reads = ReadSnapshots();
  late final ProfileRepository profile;
  late final MatchesRepository matches;
  late final PrivacyRepository privacy;
  late final DiscoveryRepository discovery;
  late final DeviceRepository devices;
  late final RealtimeHub realtime;
  late final DraftController drafts;
  late String _key;

  String get _currentKey =>
      '${session.resourceKey}:${session.localizationRevision}:${session.phase.name}';

  void _changed() {
    if (_key == _currentKey) return;
    _key = _currentKey;
    _reads.clear();
    devices.clearCache();
    if (session.phase != SessionPhase.ready) realtime.reset();
  }

  void dispose() {
    drafts.dispose();
    session.removeListener(_changed);
    _reads.clear();
    devices.clearCache();
    realtime.dispose();
  }
}
