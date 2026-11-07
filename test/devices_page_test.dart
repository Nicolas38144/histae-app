import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_preferences.dart';
import 'package:histae_app/features/notifications/presentation/devices_page.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/notifications_fixture.dart';

void main() {
  testWidgets(
    'the device switch disables and re-enables registration without a confirmation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var registered = false, posts = 0, deletes = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/notification-preferences') {
          return jsonResponse({
            for (final c in NotificationCategory.values) c.key: true,
            'discreet': false,
          });
        }
        if (r.url.path == '/api/users/me/devices') {
          if (r.method == 'POST') {
            registered = true;
            posts++;
            return jsonResponse(deviceJson(), 201);
          }
          return jsonResponse({
            'devices': [if (registered) deviceJson()],
          });
        }
        if (r.method == 'DELETE' && r.url.path.endsWith('/$deviceOne')) {
          registered = false;
          deletes++;
          return http.Response('', 204);
        }
        return defaultNotificationsResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final gateway = FakePushGateway();
      addTearDown(gateway.close);
      final push = PushController(
        DeviceRepository(session),
        gateway,
        MemoryPushVault(),
        appVersion: () async => '1.0.6',
      );
      addTearDown(push.dispose);
      await push.start();
      await push.enable();
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: DevicesPage(session: session, push: push),
        ),
      );
      await tester.pumpAndSettle();
      final control = find.byKey(const Key('device-notifications-switch'));
      await tester.scrollUntilVisible(control, 100);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(control).value, true);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(push.enabled, false);
      expect(deletes, 1);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(control).value, false);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(push.enabled, true);
      expect(posts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
