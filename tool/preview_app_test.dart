// Manual visual previews only: synthetic account and HTTP responses.
// flutter test tool/preview_app_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/profile_fixture.dart';
import '../test/support/discovery_fixture.dart';
import '../test/support/matches_fixture.dart';

import 'package:histae_app/features/matches/presentation/chat_page.dart';

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
    await tester.ensureVisible(find.text('Vos rencontres'));
    await tester.tap(find.text('Vos rencontres'));
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
    await tester.scrollUntilVisible(
      find.text('Découvrir les profils'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Découvrir les profils'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Découvrir les profils'));
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
}
