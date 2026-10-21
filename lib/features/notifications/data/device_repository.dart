import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'notification_models.dart';

abstract interface class DeviceRepository {
  factory DeviceRepository(
    AuthenticatedSession session, {
    ReadSnapshots? cache,
  }) = ApiDeviceRepository;

  AuthenticatedSession get session;
  void clearCache();

  Future<List<PushDevice>> list(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<PushDevice> register(
    DeviceRegistration intent,
    RequestCancellation scope,
  );

  Future<void> remove(String id, RequestCancellation scope);
}

final class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(this.session, {ReadSnapshots? cache})
    : _reads = cache ?? ReadSnapshots();
  final ReadSnapshots _reads;
  String get _scopeKey => '${session.resourceKey}:${session.language.code}';
  @override
  final AuthenticatedSession session;
  @override
  void clearCache() => _reads.invalidate({DataResource.devices});

  @override
  Future<List<PushDevice>> list(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.devices,
    policy: policy,
    tags: {DataResource.devices},
    cancellation: scope,
    fetch: () => _fetchList(scope),
  );

  Future<List<PushDevice>> _fetchList(RequestCancellation scope) async =>
      List.unmodifiable(
        jsonField<List<dynamic>>(
          jsonObject(
            await session.request(
              'GET',
              '/api/users/me/devices',
              expectedStatus: 200,
              replayAfterRefresh: true,
              cancellation: scope,
            ),
          ),
          'devices',
        ).map(PushDevice.fromJson),
      );

  @override
  Future<PushDevice> register(
    DeviceRegistration intent,
    RequestCancellation scope,
  ) async => _reads.mutate(
    {DataResource.devices},
    () async => PushDevice.fromJson(
      await session.request(
        'POST',
        '/api/users/me/devices',
        expectedStatus: 201,
        replayAfterRefresh: true,
        cancellation: scope,
        body: intent.body,
      ),
    ),
  );

  @override
  Future<void> remove(String id, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await _reads.mutate(
      {DataResource.devices},
      () => session.request(
        'DELETE',
        '/api/users/me/devices/$id',
        expectedStatus: 204,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    );
  }
}
