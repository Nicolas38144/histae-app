// Manual visual previews only: synthetic account and HTTP responses.
// flutter test tool/preview_app_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:histae_app/features/privacy/presentation/privacy_hub_page.dart';
import 'package:histae_app/features/privacy/presentation/report_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/discovery_fixture.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/notifications_fixture.dart';
import '../test/support/privacy_fixture.dart';
import '../test/support/profile_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final serif = FontLoader('DMSerifDisplay')
      ..addFont(
        rootBundle.load(
          'assets/fonts/dm_serif_display/DMSerifDisplay-Regular.ttf',
        ),
      );
    await serif.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) {
      throw StateError('Set FLUTTER_ROOT to render preview fonts.');
    }
    final sans = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final file = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
      );
      sans.addFont(
        Future.value(ByteData.sublistView(await file.readAsBytes())),
      );
    }
    await sans.load();
    final iconFile = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(await iconFile.readAsBytes())),
      );
    await icons.load();
  });
  testWidgets(
    'preview L8 devices, explicit removal and disabled notifications',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var hasDevice = true;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/devices' && r.method == 'GET') {
          return jsonResponse({
            'devices': [if (hasDevice) deviceJson()],
          });
        }
        if (r.method == 'DELETE' && r.url.path.endsWith(deviceOne)) {
          hasDevice = false;
        }
        return defaultNotificationsResponse(r);
      });
      await session.establish(testTokens);
      final gateway = FakePushGateway()..available = false;
      final push = PushController(
        DeviceRepository(session),
        gateway,
        MemoryPushVault(),
      );
      const preview = Key('devices-preview');
      Future<void> tapText(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: HistaeApp(sessionController: session, pushController: push),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Appareils et notifications'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText('Appareils et notifications');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/devices-overview.png'),
      );
      await tester.scrollUntilVisible(
        find.text('Retirer cet appareil'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Retirer cet appareil'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/devices-list.png'),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Retirer cet appareil'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Retirer cet appareil'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/devices-accessible.png'),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tapText('Retirer cet appareil');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/devices-remove-confirmation.png'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun appareil enregistré pour les notifications.'),
        findsOneWidget,
      );
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/devices-empty.png'),
      );
      expect(gateway.initializations, 0);
      expect(gateway.requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await gateway.close();
    },
  );
  testWidgets(
    'preview L8 simulated foreground notice and authorized conversation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = testSession((r) async => defaultNotificationsResponse(r));
      await session.establish(testTokens);
      final gateway = FakePushGateway();
      final vault = MemoryPushVault()
        ..record = const PushRecord(
          'https://api.example',
          testUser,
          deviceId: deviceOne,
        );
      final push = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () async => '1.0',
      );
      const preview = Key('push-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: HistaeApp(sessionController: session, pushController: push),
        ),
      );
      await tester.pumpAndSettle();
      gateway.foreground.add(
        const PushIntent(notificationOne, PushKind.newMessage, testMatch),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/push-foreground.png'),
      );
      await tester.tap(find.text('Consulter'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/push-conversation.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await gateway.close();
    },
  );
  testWidgets(
    'preview L7 privacy before onboarding, navigation, deletion and report',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = testSession((r) async {
        if (r.method == 'DELETE' && r.url.path == '/api/users/me') {
          return jsonResponse({
            'request_id': privacyId,
            'status': 'in_progress',
          }, 202);
        }
        return defaultPrivacyResponse(r, complete: false);
      });
      await session.establish(testTokens);
      const preview = Key('privacy-preview');
      Future<void> tapText(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: HistaeApp(sessionController: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sessions, données et suppression du compte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText('Sessions, données et suppression du compte');
      expect(find.byType(PrivacyHubPage), findsOneWidget);
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-hub.png'),
      );
      await tapText('Mes sessions');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-sessions.png'),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mes demandes de données'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tapText('Mes demandes de données');
      expect(find.textContaining('Reçue ·'), findsOneWidget);
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-rights.png'),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('privacy-right-choice')),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.byKey(const Key('privacy-right-choice')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-accessible.png'),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Exporter mes données'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tapText('Exporter mes données');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-export.png'),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Supprimer mon compte'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tapText('Supprimer mon compte');
      await tester.scrollUntilVisible(
        find.text('Supprimer définitivement mon compte'),
        140,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.text('Supprimer définitivement mon compte'),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Supprimer définitivement mon compte',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'SUPPRIMER');
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-deletion.png'),
      );
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Supprimer mon compte'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyHubPage), findsNothing);
      expect(
        find.textContaining('le nettoyage de vos données continue'),
        findsOneWidget,
      );
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-deletion-accepted.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final ready = testSession((r) async => defaultPrivacyResponse(r));
      await ready.establish(testTokens);
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: histaeTheme(Brightness.dark),
            home: ReportPage(session: ready, target: candidateOne),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/report.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: histaeTheme(Brightness.dark),
            home: PrivacyHubPage(
              session: ready,
              exportStore: PreviewExportStore(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Personnes bloquées'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tapText('Personnes bloquées');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/privacy-blocks.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      ready.dispose();
    },
  );
  testWidgets(
    'preview L6 continuation, cost consent and credits with synthetic responses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var continued = false;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [
              {
                ...publicMatchJson(status: 'awaiting_continuation'),
                'my_continued': continued,
              },
            ],
            'next_cursor': null,
          });
        }
        if (r.url.path.endsWith('/continue')) {
          continued = true;
          return jsonResponse({
            'message': 'recorded',
            'match_confirmed': false,
          });
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      const preview = Key('continuation-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: HistaeApp(sessionController: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('main-tab-matches')));
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Léa, 27'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir la suite'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/continuation.png'),
      );
      await tester.scrollUntilVisible(
        find.text('Lire le coût et choisir de continuer'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Lire le coût et choisir de continuer'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/continuation-cost.png'),
      );
      await tester.tap(find.text('Accepter 1 crédit maximum'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/continuation-recorded.png'),
      );
      await tester.ensureVisible(find.text('Voir mes crédits'));
      await tester.tap(find.text('Voir mes crédits'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/credits.png'),
      );
      await tester.scrollUntilVisible(
        find.text('Une vidéo, si vous le souhaitez'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/credits-videos-disabled.png'),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('preview L5 matches and chat with synthetic conversations only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var status = 'active';
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [publicMatchJson(status: status)],
          'next_cursor': null,
        });
      }
      if (r.url.path == '/api/matches/$testMatch/messages') {
        return jsonResponse({
          'messages': [
            messageJson(
              id: outgoingId,
              sender: testUser,
              content: 'Les livres qui donnent envie de partir, sans hésiter.',
              readAt: '2026-10-16T12:01:00Z',
            ),
            messageJson(
              content: 'Et si on parlait de nos lectures ? Quel livre t’a donné envie de voyager ?',
            ),
          ],
          'next_cursor': null,
        });
      }
      return defaultMatchesResponse(r);
    });
    await session.establish(testTokens);
    const preview = Key('matches-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('main-tab-matches')));
    await tester.tap(find.byKey(const Key('main-tab-matches')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/matches.png'),
    );
    await tester.tap(find.text('Léa, 27'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/chat.png'),
    );
    status = 'awaiting_continuation';
    await tester.tap(find.byTooltip('Actualiser la conversation'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/chat-paused.png'),
    );
    // Inspect the actual layout under a small keyboard viewport and large text.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/chat-accessible.png'),
    );
    // Closing the conversation also checks parent navigation after cancellation.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('preview L4 discovery with synthetic profiles only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = testSession(
      (request) async => defaultDiscoveryResponse(request),
    );
    await session.establish(testTokens);
    const preview = Key('discovery-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/feed.png'),
    );
    await tester.drag(
      find.byKey(const Key('feed-profile-scroll')),
      const Offset(0, -210),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/feed-end.png'),
    );
  });
  testWidgets('preview welcome, registration and consent direction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = testSession(
      (request) async => defaultAuthResponse(request),
    );
    const preview = Key('visual-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/welcome.png'),
    );
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/registration.png'),
    );
    await session.establish(testTokens);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/consents.png'),
    );
  });
  testWidgets('preview L3 profile and identity with synthetic owner data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = testSession(
      (request) async => defaultProfileResponse(request),
    );
    await session.establish(testTokens);
    const preview = Key('profile-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-profile')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/profile.png'),
    );
    await tester.scrollUntilVisible(
      find.text('Modifier ma présentation'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Modifier ma présentation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier ma présentation'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/profile-editor.png'),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Écrire mes réponses'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Écrire mes réponses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écrire mes réponses'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/answers.png'),
    );
  });
  testWidgets('preview main bottom navigation in dark mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = testSession((r) async => defaultMatchesResponse(r));
    await session.establish(testTokens);
    const preview = Key('main-navigation-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['discovery', 'matches', 'profile']) {
      await tester.tap(find.byKey(Key('main-tab-$tab')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile('../build/previews/main-$tab.png'),
      );
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('../build/previews/main-navigation-large-text.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
