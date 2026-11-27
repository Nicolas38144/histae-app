import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/help/presentation/casework_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:histae_app/features/privacy/application/privacy_controller.dart';
import 'package:histae_app/features/privacy/presentation/privacy_detail_page.dart';
import 'package:histae_app/features/privacy/presentation/privacy_notification_page.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';
import 'support/privacy_fixture.dart';

void main() {
  testWidgets('casework push opens only the authenticated dossier', (
    tester,
  ) async {
    final opened = <String>[];
    final support = '/api/users/me/support-cases/$privacyId';
    final rights = '/api/users/me/data-subject-requests';
    final thread = '$rights/$privacyId/messages';
    const exportRequest = '12121212-1212-4212-8212-121212121212';
    const exportGrant = '23232323-2323-4232-8232-232323232323';
    const exportNotice = '34343434-3434-4343-8343-343434343434';
    final exportThread = '$rights/$exportRequest/messages';
    final grantPath = '$rights/$exportRequest/assisted-export';
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 1));
    final session = testSession((request) async {
      final path = request.url.path;
      if (path == support) {
        opened.add(path);
        return jsonResponse({
          'id': privacyId,
          'category': 'other',
          'status': 'closed',
          'body': 'Private support request',
          'response': 'Private support update',
        });
      }
      if (path == rights) {
        opened.add(path);
        return jsonResponse({
          'requests': [
            rightsJson(type: 'rectification'),
            {...rightsJson(status: 'in_progress'), 'id': exportRequest},
          ],
        });
      }
      if (path == thread) {
        opened.add(path);
        return jsonResponse({
          'details': null,
          'status': 'completed',
          'messages': [
            {
              'id': notificationTwo,
              'author': 'team',
              'body': 'Private RGPD reply',
            },
          ],
          'next_cursor': null,
        });
      }
      if (path == exportThread) {
        opened.add(path);
        return jsonResponse({
          'details': null,
          'status': 'in_progress',
          'messages': <Object?>[],
          'next_cursor': null,
        });
      }
      if (path == grantPath) {
        opened.add(path);
        return jsonResponse({
          'id': exportGrant,
          'expires_at': expiresAt.toIso8601String(),
        });
      }
      return defaultNotificationsResponse(request);
    });
    await session.establish(testTokens);
    final gateway = FakePushGateway();
    final vault = MemoryPushVault()
      ..record = const PushRecord(
        'https://api.example',
        testUser,
        deviceId: deviceOne,
      );
    final push = PushController(DeviceRepository(session), gateway, vault);
    await tester.pumpWidget(
      HistaeApp(
        sessionController: session,
        pushController: push,
        privacyExportStore: PreviewExportStore(),
      ),
    );
    await tester.pumpAndSettle();
    gateway.taps.add(
      PushIntent.parse({
        'notification_id': notificationOne,
        'type': 'support_case_updated',
        'support_case_id': privacyId,
      })!,
    );
    await tester.pumpAndSettle();
    expect(opened, [support]);
    expect(find.text('Private support update'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    gateway.taps.add(
      PushIntent.parse({
        'notification_id': notificationTwo,
        'type': 'data_request_replied',
        'request_id': privacyId,
        'request_message_id': notificationOne,
      })!,
    );
    await tester.pumpAndSettle();
    expect(opened, [support, rights, thread]);
    expect(
      tester.widget<CaseworkPage>(find.byType(CaseworkPage)).view,
      CaseworkView.thread,
    );
    expect(find.text('Private RGPD reply'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    gateway.taps.add(
      PushIntent.parse({
        'notification_id': exportNotice,
        'type': 'data_request_replied',
        'request_id': exportRequest,
        'request_event': 'export_ready',
      })!,
    );
    await tester.pumpAndSettle();
    expect(opened.last, grantPath);
    expect(opened, contains(exportThread));
    final export = find.text('Télécharger l’export assisté');
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PrivacyDetailPage>(find.byType(PrivacyDetailPage))
          .assistedExportId,
      exportGrant,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(export, findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(export, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await gateway.close();
  });

  for (final kind in [PushKind.dataRequestReplied, PushKind.newSession]) {
    testWidgets('${kind.name} opens a fresh owner-scoped privacy destination', (
      tester,
    ) async {
      final requests = kind == PushKind.dataRequestReplied;
      final endpoint = requests
          ? '/api/users/me/data-subject-requests'
          : '/api/auth/sessions';
      var reads = 0;
      final session = testSession((request) async {
        if (request.url.path == endpoint) reads++;
        if (requests && request.url.path == endpoint) {
          return jsonResponse({
            'requests': [
              {
                ...rightsJson(type: 'rectification', status: 'completed'),
                'completed_at': '2026-11-05T12:00:00Z',
                'details': 'Une correction de test.',
                'response': reads == 1
                    ? 'Première réponse de test.'
                    : 'Réponse de test mise à jour.',
              },
            ],
          });
        }
        return request.url.path == '/api/auth/sessions'
            ? defaultPrivacyResponse(request)
            : defaultNotificationsResponse(request);
      });
      await session.establish(testTokens);
      final vault = MemoryPushVault()
        ..record = const PushRecord(
          'https://api.example',
          testUser,
          deviceId: deviceOne,
        );
      final gateway = FakePushGateway();
      final push = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () async => '1.0',
      );
      await tester.pumpWidget(
        HistaeApp(
          sessionController: session,
          pushController: push,
          privacyExportStore: PreviewExportStore(),
        ),
      );
      await tester.pumpAndSettle();
      for (final id in [notificationOne, notificationTwo]) {
        gateway.taps.add(
          PushIntent(id, kind, null, requestId: requests ? privacyId : null),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyNotificationPage), findsOneWidget);
        final detail = tester.widget<PrivacyDetailPage>(
          find.byType(PrivacyDetailPage),
        );
        expect(
          detail.section,
          requests ? PrivacySection.rights : PrivacySection.sessions,
        );
        expect(detail.controller.repository.owner, testUser);
        if (requests) {
          expect(
            detail.controller.rights.single.response,
            reads == 1
                ? 'Première réponse de test.'
                : 'Réponse de test mise à jour.',
          );
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(
        reads,
        2,
        reason: 'notification opens bypass an earlier private snapshot',
      );
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyNotificationPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await gateway.close();
    });
  }
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
          PushKind.photosRevealed,
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
