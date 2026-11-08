// Manual visual review only; all accounts, ads and server responses are fake.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consents_page.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/data/profile_models.dart';
import 'package:histae_app/features/profile/presentation/profile_feed_preview_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/profile_fixture.dart';
import '../test/support/scrolling.dart';

String _limitBiography() {
  final sample = List.filled(
    12,
    'J’aime les dimanches où une balade finit en café avec des amis. '
    'Je rapporte souvent un livre ou une recette de mes voyages, et je prends '
    'toujours le temps de les partager. Racontez-moi ce qui vous occupe en ce moment.',
  ).join('\n\n');
  var result = '';
  for (final character in sample.characters) {
    if (biographyByteLength('$result$character') > biographyByteLimit) break;
    result += character;
  }
  result = result.trim();
  return result + '.' * (biographyByteLimit - biographyByteLength(result));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Inter', 'inter/Inter-Variable.ttf'),
      ('SourceSerif4', 'source_serif_4/SourceSerif4-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
    final bytes = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets('review owner photo and footer in each language', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final portrait = (await tester.runAsync(
      () => File('pictures/fixtures/fictional-portrait.png').readAsBytes(),
    ))!;
    final session = testSession(
      (r) async => r.url.path == '/api/users/me'
          ? jsonResponse(
              ownerJson(photo: 'https://storage.example/owner-preview'),
            )
          : defaultProfileResponse(r),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final controller = ProfileController(ProfileRepository(session));
    addTearDown(controller.dispose);
    await controller.load();
    const frame = Key('owner-spacing-preview');
    for (final language in ['fr', 'en', 'es', 'it']) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(language),
          debugShowCheckedModeBanner: false,
          theme: histaeTheme(Brightness.dark),
          locale: Locale(language),
          supportedLocales: AppMessages.supportedLocales,
          localizationsDelegates: AppMessages.localizationsDelegates,
          home: RepaintBoundary(
            key: frame,
            child: ProfileFeedPreviewPage(
              controller: controller,
              photoClient: () =>
                  MockClient((_) async => http.Response.bytes(portrait, 200)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final photo = find.byType(Image);
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(photo).image,
          tester.element(photo),
        ),
      );
      await tester.pumpAndSettle();
      if (language == 'fr') {
        await expectLater(
          find.byKey(frame),
          matchesGoldenFile('../build/previews/profile/owner-top.png'),
        );
      }
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(frame),
        matchesGoldenFile(
          '../build/previews/profile/owner-footer-$language.png',
        ),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('review profile, answer management and consent clarity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var paused = false;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/discovery-settings')) {
        if (r.method == 'PATCH') paused = jsonDecode(r.body)['paused'] as bool;
        return jsonResponse({'paused': paused});
      }
      if (r.url.path.endsWith('/consents')) {
        return jsonResponse(
          consentJson(
            complete: true,
            grants: {ConsentType.sensitive: true, ConsentType.location: true},
          ),
        );
      }
      if (r.url.path == '/api/profile-questions') {
        return jsonResponse({
          'questions': [
            questionJson(questionOne, 'Votre dimanche idéal ?', 1),
            questionJson(questionTwo, 'Le petit bonheur qui change tout ?', 2),
            questionJson(
              '66666666-6666-4666-8666-666666666666',
              'Ce que vous aimeriez apprendre ?',
              3,
            ),
          ],
        });
      }
      if (r.url.path.endsWith('/profile-answers')) {
        return jsonResponse({
          'answers': [
            {
              ...answerJson(
                questionOne,
                'Une longue balade, un café au soleil et aucune heure à regarder.',
                0,
              ),
              'moderation_status': 'approved',
            },
            {
              ...answerJson(
                questionTwo,
                'Un message inattendu, ou un livre que je n’arrive plus à lâcher.',
                1,
              ),
              'question': 'Le petit bonheur qui change tout ?',
            },
          ],
        });
      }
      return defaultContinuationResponse(r);
    });
    await session.establish(testTokens);
    const frame = Key('profile-preview');
    Future<void> capture(String name) => expectLater(
      find.byKey(frame),
      matchesGoldenFile('../build/previews/profile/$name.png'),
    );
    Future<void> reveal(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        tester
            .state<ScrollableState>(verticalScrollables.first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: verticalScrollables.first,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: HistaeApp(sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-profile')));
    await tester.pumpAndSettle();
    await capture('overview');
    await reveal(find.text('Modifier ma présentation'));
    await tester.tap(find.text('Modifier ma présentation'));
    await tester.pumpAndSettle();
    await capture('identity');
    final biography = find.widgetWithText(TextField, 'Quelques mots sur vous');
    await reveal(biography);
    await tester.enterText(biography, _limitBiography());
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture('identity-limit');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    await reveal(find.byKey(const Key('profile-feed-preview')));
    await tester.tap(find.byKey(const Key('profile-feed-preview')));
    await tester.pumpAndSettle();
    await capture('feed-preview');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await capture('feed-preview-large');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await tester.pumpAndSettle();
    await reveal(find.byKey(const Key('discovery-paused')));
    await tester.tap(find.byKey(const Key('discovery-paused')));
    await tester.pumpAndSettle();
    await capture('pause-active');
    await tester.tap(find.byKey(const Key('discovery-paused')));
    await tester.pumpAndSettle();
    await reveal(find.text('Des débuts de conversation'));
    await tester.drag(verticalScrollables.first, const Offset(0, 110));
    await tester.pumpAndSettle();
    await capture('answers-preview');
    await reveal(find.text('Ce qui vous ressemble'));
    await capture('details');
    await reveal(find.text('Écrire mes réponses'));
    await tester.tap(find.text('Écrire mes réponses'));
    await tester.pumpAndSettle();
    await capture('editor');
    await reveal(find.widgetWithText(TextField, 'Réponse 1'));
    await capture('editor-answer');
    await reveal(find.text('Ajouter une question'));
    await tester.tap(find.text('Ajouter une question'));
    await tester.pumpAndSettle();
    await capture('question-picker');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    await capture('question-picker-keyboard-large');
    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fermer les questions'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await capture('editor-large');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await capture('profile-large');
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => ConsentsPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await capture('consents');
    await reveal(find.text('Vos documents nécessaires'));
    await capture('consents-documents');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await capture('consents-large');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
