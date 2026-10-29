import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';

void main() {
  testWidgets(
    'cold notification checks session and match membership; stale match stays closed, warm delivery deduplicates and logout forgets navigation',
    (tester) async {
      final paths = <String>[];
      final session = testSession((r) async {
        paths.add(r.url.path);
        return defaultNotificationsResponse(r);
      });
      await session.establish(testTokens);
      final vault = MemoryPushVault()
        ..record = const PushRecord(
          'https://api.example',
          testUser,
          deviceId: deviceOne,
        );
      final gateway = FakePushGateway()
        ..first = const PushIntent(
          notificationOne,
          PushKind.newMatch,
          secondMatch,
        );
      final push = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () async => '1.0',
      );
      await tester.pumpWidget(
        HistaeApp(sessionController: session, pushController: push),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MatchesPage), findsOneWidget);
      expect(find.byType(ChatPage), findsNothing);
      expect(paths.any((p) => p.contains('/$secondMatch/messages')), isFalse);
      expect(paths.any((p) => p == '/api/matches/$secondMatch'), isFalse);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final valid = PushIntent.parse({
        'notification_id': notificationTwo,
        'type': 'new_message',
        'match_id': testMatch,
        'title': 'PRIVATE REMOTE TITLE',
        'body': 'PRIVATE REMOTE TEXT',
        'url': 'https://untrusted.invalid',
      })!;
      gateway.foreground.add(valid);
      await tester.pumpAndSettle();
      expect(find.text('Une mise à jour Histae est disponible.'), findsNothing);
      expect(find.textContaining('PRIVATE REMOTE'), findsNothing);
      expect(find.byType(ChatPage), findsNothing);
      gateway.taps.add(valid);
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(paths.any((p) => p.contains('/$testMatch/messages')), isTrue);
      gateway.taps.add(valid);
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Un brouillon conservé');
      gateway.taps.add(
        const PushIntent(
          'efefefef-efef-4fef-8fef-efefefefefef',
          PushKind.newMessage,
          testMatch,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(find.text('Un brouillon conservé'), findsOneWidget);
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsNothing);
      expect(push.pendingOpen, isNull);
      gateway.taps.add(valid);
      await tester.pumpAndSettle();
      expect(push.pendingOpen, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await gateway.close();
    },
  );
}
