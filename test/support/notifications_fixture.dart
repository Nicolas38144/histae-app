import 'dart:async';

import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_gateway.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'matches_fixture.dart';

const deviceOne = 'abababab-abab-4bab-8bab-abababababab';
const deviceTwo = 'bcbcbcbc-bcbc-4cbc-8cbc-bcbcbcbcbcbc';
const notificationOne = 'cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd';
const notificationTwo = 'dededede-dede-4ede-8ede-dededededede';
const syntheticRegistration = 'synthetic-fcm-installation-one';
Map<String, Object?> deviceJson({
  String id = deviceOne,
  String platform = 'android',
}) => {
  'id': id,
  'session_id': null,
  'platform': platform,
  'app_version': '1.0.0+1',
  'created_at': '2026-10-17T00:00:00Z',
  'last_used_at': null,
};
http.Response defaultNotificationsResponse(http.Request r) =>
    switch (r.url.path) {
      '/api/users/me/devices' =>
        r.method == 'POST'
            ? jsonResponse(deviceJson(), 201)
            : jsonResponse({
                'devices': [deviceJson()],
              }),
      '/api/users/me/devices/$deviceOne' ||
      '/api/users/me/devices/$deviceTwo' => http.Response('', 204),
      _ => defaultMatchesResponse(r),
    };

class MemoryPushVault implements PushVault {
  PushRecord? record;
  final writes = <String>[];
  bool fail = false;
  @override
  Future<PushRecord?> read() async => record;
  @override
  Future<void> write(PushRecord? value) async {
    if (fail) throw StateError('Synthetic locked storage');
    record = value;
    writes.add(value?.encode() ?? '{}');
  }
}

class FakePushGateway implements PushGateway {
  bool available = true, failDisable = false;
  int initializations = 0, requests = 0, registrationsCount = 0, disables = 0;
  String registrationId = syntheticRegistration;
  PushPermission authorization = PushPermission.authorized;
  PushIntent? first;
  final tokens = StreamController<String>.broadcast(sync: true);
  final foreground = StreamController<PushIntent>.broadcast(sync: true);
  final taps = StreamController<PushIntent>.broadcast(sync: true);
  @override
  bool get configured => available;
  @override
  String get platform => 'android';
  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) requests++;
    return authorization;
  }

  @override
  Future<String> registration() async {
    registrationsCount++;
    return registrationId;
  }

  @override
  Future<void> disable() async {
    disables++;
    if (failDisable) throw StateError('Synthetic provider failure');
  }

  @override
  Future<PushIntent?> initial() async => first;
  @override
  Stream<String> get registrations => tokens.stream;
  @override
  Stream<PushIntent> get received => foreground.stream;
  @override
  Stream<PushIntent> get opened => taps.stream;
  Future<void> close() async {
    await tokens.close();
    await foreground.close();
    await taps.close();
  }
}
