import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/core/config/push_config.dart';
import 'package:histae_app/features/auth/data/session_vault.dart';
import 'package:histae_app/features/notifications/application/devices_controller.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_gateway.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';

void main() {
  test('public Firebase configuration defaults off, rejects secrets and inconsistent sender IDs', () {
    const base = 'APP_ENV=production\nAPI_BASE_URL=https://api.example\n';
    final c = AppConfig.fromDotEnv(
      '${base}PUSH_ENABLED=false\nFIREBASE_ANDROID_API_KEY=\n',
      isDebug: false,
    );
    expect(c.push.enabled, isFalse);
    expect(c.push.androidReady, isFalse);
    expect(FirebasePushGateway(c.push).configured, isFalse);
    expect(
      () => AppConfig.fromDotEnv(
        '${base}FIREBASE_PRIVATE_KEY=secret',
        isDebug: false,
      ),
      throwsFormatException,
    );
    expect(
      () => PushConfig.fromValues({'PUSH_ENABLED': 'true'}),
      throwsFormatException,
    );
    final values = {
      'PUSH_ENABLED': 'true',
      'FIREBASE_PROJECT_ID': 'histae-synthetic',
      'FIREBASE_MESSAGING_SENDER_ID': '123456789012',
      'FIREBASE_ANDROID_API_KEY': 'synthetic-public-client-key',
      'FIREBASE_ANDROID_APP_ID': '1:123456789012:android:abc123',
    };
    expect(PushConfig.fromValues(values).androidReady, isTrue);
    expect(
      () => PushConfig.fromValues({
        ...values,
        'FIREBASE_MESSAGING_SENDER_ID': '987654321012',
      }),
      throwsFormatException,
    );
  });
  test('device list is owner authenticated and not paginated; uncertain remove resolves from GET; incomplete onboarding sends nothing', () async {
    final calls = <http.Request>[];
    var removed = false;
    final session = testSession((r) async {
      calls.add(r);
      if (r.url.path == '/api/users/me/devices') {
        expect(r.url.query, isEmpty);
        return jsonResponse({
          'devices': [if (!removed) deviceJson()],
        });
      }
      if (r.method == 'DELETE') {
        expect(r.body, isEmpty);
        removed = true;
        throw const SocketException('synthetic lost response');
      }
      return defaultNotificationsResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DevicesController(DeviceRepository(session));
    addTearDown(c.dispose);
    await c.load();
    expect(c.devices.single.sessionId, isNull);
    expect(c.devices.single.lastUsedAt, isNull);
    expect(await c.remove(deviceOne), isTrue);
    expect(c.pendingRemoval, isNull);
    expect(c.devices, isEmpty);
    expect(
      calls
          .where((r) => r.url.path.contains('/devices'))
          .every(
            (r) =>
                r.headers['Authorization'] ==
                'Bearer ${testTokens.accessToken}',
          ),
      isTrue,
    );
    final pending = testSession((r) async => defaultAuthResponse(r));
    addTearDown(pending.dispose);
    await pending.establish(testTokens);
    final hidden = DevicesController(DeviceRepository(pending));
    addTearDown(hidden.dispose);
    await hidden.load();
    expect(hidden.accessible, isFalse);
    expect(hidden.devices, isEmpty);
  });
  test('disabled gateway never initializes or asks permission while device management remains usable', () async {
    final session = testSession((r) async => defaultNotificationsResponse(r));
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway()..available = false;
    addTearDown(gateway.close);
    final p = PushController(
      DeviceRepository(session),
      gateway,
      MemoryPushVault(),
    );
    addTearDown(p.dispose);
    await p.start();
    await p.enable();
    await pumpEventQueue();
    expect(gateway.initializations, 0);
    expect(gateway.requests, 0);
    expect(gateway.registrationsCount, 0);
    expect(p.enabled, isFalse);
    final c = DevicesController(DeviceRepository(session));
    addTearDown(c.dispose);
    await c.load();
    expect(c.devices.single.id, deviceOne);
  });
  test('permission denial never registers; double enable is serialized; rotation retires the old public device without persisting provider ID', () async {
    final bodies = <Map<String, dynamic>>[], removed = <String>[];
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/devices' && r.method == 'POST') {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return jsonResponse(
          deviceJson(id: bodies.length == 1 ? deviceOne : deviceTwo),
          201,
        );
      }
      if (r.method == 'DELETE') {
        removed.add(r.url.path);
        return http.Response('', 204);
      }
      return defaultNotificationsResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway()..authorization = PushPermission.denied;
    addTearDown(gateway.close);
    final vault = MemoryPushVault();
    final p = PushController(
      DeviceRepository(session),
      gateway,
      vault,
      appVersion: () async => '2.3.0+12',
    );
    addTearDown(p.dispose);
    await p.start();
    await pumpEventQueue();
    await Future.wait([p.enable(), p.enable()]);
    expect(gateway.requests, 1);
    expect(gateway.registrationsCount, 0);
    expect(bodies, isEmpty);
    gateway.authorization = PushPermission.authorized;
    await p.enable();
    expect(bodies.single, {
      'push_token': syntheticRegistration,
      'platform': 'android',
      'app_version': '2.3.0+12',
      'language': null,
    });
    gateway.tokens.add('synthetic-fcm-installation-two');
    await pumpEventQueue();
    expect(p.deviceId, deviceTwo);
    expect(removed, ['/api/users/me/devices/$deviceOne']);
    expect(vault.writes.any((v) => v.contains('synthetic-fcm')), isFalse);
    expect(vault.record!.deviceId, deviceTwo);
  });
  test('lost registration response freezes exact provider ID and version until explicit retry', () async {
    final bodies = <String>[];
    var failPost = true;
    final session = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/devices')) {
        bodies.add(r.body);
        if (failPost) throw const SocketException('synthetic');
        return jsonResponse(deviceJson(), 201);
      }
      return defaultNotificationsResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway();
    addTearDown(gateway.close);
    final p = PushController(
      DeviceRepository(session),
      gateway,
      MemoryPushVault(),
      appVersion: () async => '1.2.3',
    );
    addTearDown(p.dispose);
    await p.start();
    await pumpEventQueue();
    await p.enable();
    expect(p.pending, isNotNull);
    expect(bodies.length, 1);
    gateway.registrationId = 'synthetic-new-id-not-to-send';
    await p.resume();
    expect(bodies.length, 1);
    failPost = false;
    await p.enable();
    expect(bodies[1], bodies[0]);
    expect(gateway.registrationsCount, 1);
    expect(p.pending, isNull);
  });
  test('cold restore verifies owner and remote device existence before registration; removed devices never resurrect', () async {
    for (final mismatch in [false, true]) {
      var posts = 0;
      final session = testSession((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/devices')) posts++;
        if (r.url.path.endsWith('/devices') && r.method == 'GET') {
          return jsonResponse({'devices': <Object?>[]});
        }
        return defaultNotificationsResponse(r);
      });
      await session.establish(testTokens);
      final gateway = FakePushGateway();
      final vault = MemoryPushVault()
        ..record = PushRecord(
          'https://api.example',
          mismatch ? deviceTwo : testUser,
          deviceId: deviceOne,
        );
      final p = PushController(DeviceRepository(session), gateway, vault);
      await p.start();
      await pumpEventQueue();
      expect(posts, 0);
      expect(gateway.registrationsCount, 0);
      expect(vault.record, isNull);
      expect(p.enabled, isFalse);
      expect(gateway.disables, 1);
      p.dispose();
      session.dispose();
      await gateway.close();
    }
    final authVault = MemorySessionVault()
      ..value = const SessionRecord(
        'https://api.example',
        'ready',
        'test-refresh-old',
      ).encode();
    final me = Completer<http.Response>();
    final restoring = testSession(
      (r) async => r.url.path == '/api/auth/me'
          ? me.future
          : defaultNotificationsResponse(r),
      vault: authVault,
    );
    final gateway = FakePushGateway()
      ..first = const PushIntent(notificationTwo, PushKind.newMatch, testMatch);
    final vault = MemoryPushVault()
      ..record = const PushRecord(
        'https://api.example',
        testUser,
        deviceId: deviceOne,
      );
    final push = PushController(
      DeviceRepository(restoring),
      gateway,
      vault,
      appVersion: () async => '1.0',
    );
    final bootstrap = restoring.start();
    await pumpEventQueue();
    await push.start();
    expect(vault.record, isNotNull);
    me.complete(jsonResponse(identityJson(complete: true)));
    await bootstrap;
    await pumpEventQueue();
    expect(push.enabled, isTrue);
    expect((await push.authorizeOpen())?.id, notificationTwo);
    push.dispose();
    restoring.dispose();
    await gateway.close();
  });
  test(
    'logout discards late token rotation and account-scoped notification state',
    () async {
      var versions = 0, posts = 0;
      final nextVersion = Completer<String?>();
      final session = testSession((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/devices')) posts++;
        return defaultNotificationsResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final gateway = FakePushGateway();
      addTearDown(gateway.close);
      final vault = MemoryPushVault();
      final p = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () =>
            ++versions == 1 ? Future.value('1.0') : nextVersion.future,
      );
      addTearDown(p.dispose);
      await p.start();
      await pumpEventQueue();
      await p.enable();
      gateway.tokens.add('synthetic-late-rotated-id');
      await pumpEventQueue();
      await session.logout();
      expect(p.enabled, isFalse);
      expect(p.pending, isNull);
      nextVersion.complete('1.1');
      await pumpEventQueue();
      expect(posts, 1);
      expect(p.pending, isNull);
      expect(vault.record, isNull);
      gateway.taps.add(
        const PushIntent(notificationOne, PushKind.newMatch, testMatch),
      );
      expect(p.pendingOpen, isNull);
    },
  );
  test('failed local stop persists an opt-out tombstone and retries cleanup after restart without auto-registering', () async {
    var posts = 0;
    final session = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/devices')) posts++;
      return defaultNotificationsResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway();
    addTearDown(gateway.close);
    final vault = MemoryPushVault();
    final p = PushController(
      DeviceRepository(session),
      gateway,
      vault,
      appVersion: () async => '1.0',
    );
    await p.start();
    await pumpEventQueue();
    await p.enable();
    gateway.failDisable = true;
    await p.disable();
    expect(vault.record!.optedIn, isFalse);
    expect(p.stopping, isTrue);
    p.dispose();
    gateway.failDisable = false;
    final restored = PushController(DeviceRepository(session), gateway, vault);
    addTearDown(restored.dispose);
    await restored.start();
    await pumpEventQueue();
    expect(posts, 1);
    expect(vault.record, isNull);
    expect(restored.enabled, isFalse);
    expect(restored.stopping, isFalse);
  });
  test('notification payloads are narrowed, foreground deduplicated and opened IDs survive owner-bound restart', () async {
    final payload = {
      'notification_id': notificationOne,
      'type': 'new_message',
      'match_id': testMatch,
      'url': 'https://untrusted.invalid',
      'body': 'private text never retained',
    };
    final intent = PushIntent.parse(payload)!;
    expect(intent.matchId, testMatch);
    expect(intent.toString(), isNot(contains('private')));
    expect(
      PushIntent.parse({...payload, 'match_id': 'https://untrusted.invalid'}),
      isNull,
    );
    expect(PushIntent.parse({...payload, 'type': 'open_url'}), isNull);
    final session = testSession((r) async => defaultNotificationsResponse(r));
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway();
    addTearDown(gateway.close);
    final vault = MemoryPushVault();
    final p = PushController(
      DeviceRepository(session),
      gateway,
      vault,
      appVersion: () async => '1.0',
    );
    await p.start();
    await pumpEventQueue();
    await p.enable();
    gateway.foreground.add(intent);
    expect(p.foreground?.id, notificationOne);
    p.dismiss();
    gateway.foreground.add(intent);
    expect(p.foreground, isNull);
    gateway.taps.add(intent);
    expect((await p.authorizeOpen())?.id, notificationOne);
    expect(vault.record!.opened, [notificationOne]);
    p.dispose();
    final restored = PushController(
      DeviceRepository(session),
      gateway,
      vault,
      appVersion: () async => '1.0',
    );
    addTearDown(restored.dispose);
    await restored.start();
    await pumpEventQueue();
    gateway.taps.add(intent);
    expect(restored.pendingOpen, isNull);
  });
}
