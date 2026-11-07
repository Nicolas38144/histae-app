import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'notification_preferences.dart';

/// Owned by a session feature, never persisted across accounts or app launches.
final class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this.session);
  final AuthenticatedSession session;
  final _reads = ReadSnapshots();
  static const _account = 'notification-preferences';
  static const _path = '/api/users/me/notification-preferences';

  void clear() => _reads.clear();

  Future<NotificationPreferences> account(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.cached,
  }) => _reads.read(
    scope: session.resourceKey,
    key: _account,
    policy: policy,
    tags: {_account},
    cancellation: scope,
    fetch: () async => NotificationPreferences.fromJson(
      await session.request(
        'GET',
        _path,
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    ),
  );

  Future<NotificationPreferences> changeAccount(
    Map<String, bool> changes,
    RequestCancellation scope,
  ) => _reads.mutate(
    {_account},
    () async => NotificationPreferences.fromJson(
      await session.request(
        'PATCH',
        _path,
        body: changes,
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    ),
  );

  String _matchPath(String id) {
    serverId({'id': id}, 'id');
    return '/api/matches/$id/notification-preferences';
  }

  Future<ConversationMute> conversation(
    String id,
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.cached,
  }) => _reads.read(
    scope: session.resourceKey,
    key: (_account, id),
    policy: policy,
    tags: {(_account, id)},
    cancellation: scope,
    fetch: () async => ConversationMute.fromJson(
      await session.request(
        'GET',
        _matchPath(id),
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    ),
  );

  Future<ConversationMute> mute(
    String id,
    RequestCancellation scope, {
    required bool muted,
    DateTime? until,
  }) => _reads.mutate(
    {(_account, id)},
    () async => ConversationMute.fromJson(
      await session.request(
        'PUT',
        _matchPath(id),
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: scope,
        body: {'muted': muted, 'muted_until': until?.toUtc().toIso8601String()},
      ),
    ),
  );
}
