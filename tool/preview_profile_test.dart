// Manual visual review only; all accounts, ads and server responses are fake.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consents_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/profile_fixture.dart';

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
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
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
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 110));
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
