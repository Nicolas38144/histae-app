import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import 'notification_models.dart';

abstract interface class DeviceRepository {
  factory DeviceRepository(AuthenticatedSession session) = ApiDeviceRepository;
  AuthenticatedSession get session;
  Future<List<PushDevice>> list(RequestCancellation scope);
  Future<PushDevice> register(
    DeviceRegistration intent,
    RequestCancellation scope,
  );
  Future<void> remove(String id, RequestCancellation scope);
}

final class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(this.session);
  @override
  final AuthenticatedSession session;
  @override
  Future<List<PushDevice>> list(RequestCancellation scope) async =>
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
  ) async => PushDevice.fromJson(
    await session.request(
      'POST',
      '/api/users/me/devices',
      expectedStatus: 201,
      replayAfterRefresh: true,
      cancellation: scope,
      body: intent.body,
    ),
  );
  @override
  Future<void> remove(String id, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await session.request(
      'DELETE',
      '/api/users/me/devices/$id',
      expectedStatus: 204,
      replayAfterRefresh: true,
      cancellation: scope,
    );
  }
}
