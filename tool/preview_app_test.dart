// Manual visual previews only: synthetic account and HTTP responses.
// flutter test tool/preview_app_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';

import '../test/support/auth_fixture.dart';
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
