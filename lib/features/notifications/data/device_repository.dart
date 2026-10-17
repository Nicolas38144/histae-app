import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/profile_models.dart';
import 'notification_models.dart';

class DeviceRepository {
  DeviceRepository(this.session);
  final SessionController session;
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
