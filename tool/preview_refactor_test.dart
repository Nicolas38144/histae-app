// Current screens with fictional people and simulated API responses only.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/help/presentation/help_page.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/profile/presentation/profile_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/discovery_fixture.dart';
import '../test/support/matches_fixture.dart';

const _output = String.fromEnvironment(
  'REFACTOR_PREVIEW_OUTPUT',
  defaultValue: 'build/previews/refactor',
);
const _boundary = Key('refactor-preview');
const _biography =
    'Je suis le genre de personne qui entre dans une librairie pour cinq minutes '
    'et en ressort une heure plus tard. J’aime les romans dont on reparle '
    'longtemps, les cafés qui deviennent des habitudes et les promenades '
    'où l’on change trois fois de direction.\n\n'
    'En semaine, je cuisine pour mes amis, même quand la recette part un peu '
    'de travers. Le dimanche, vous me trouverez souvent sur un sentier, '
    'un appareil photo dans le sac et quelque chose à partager pour le goûter.\n\n'
    'Racontez-moi un endroit où vous retournez toujours, ou le petit projet '
    'qui vous occupe en ce moment. Je préfère une réponse sincère à une phrase parfaite.';

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_output/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
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
    final icons = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  testWidgets(
    'capture feed, archived search, conversation details and account actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final clock = DateTime.now().toUtc();
      Map<String, dynamic> match(String id, {required bool archived}) => {
        ...publicMatchJson(
          id: id,
          status: 'confirmed',
          expiresAt: clock.add(Duration(days: archived ? 6 : 29)),
        ),
        'archived': archived,
        'inactivity_expires_at': clock
            .add(Duration(days: archived ? 6 : 29))
            .toIso8601String(),
        'unread_count': archived ? 0 : 2,
        'other_user': candidateJson(
          archived ? candidateTwo : candidateOne,
          name: archived ? 'Camille' : 'Léa',
          bio: _biography,
        ),
        'last_message': messageJson(
          match: id,
          sender: archived ? candidateTwo : candidateOne,
          content: archived
              ? 'On se raconte nos dernières lectures ?'
              : 'J’ai trouvé le livre dont tu me parlais !',
          readAt: clock.toIso8601String(),
        ),
      };
      final session = testSession((request) async {
        if (request.url.path == '/api/feed') {
          return jsonResponse({
            'profiles': [candidateJson(candidateOne, bio: _biography)],
            'next_cursor': null,
          });
        }
        if (request.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [
              match(testMatch, archived: false),
              match(secondMatch, archived: true),
            ],
            'next_cursor': null,
          });
        }
        if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
          final id = request.url.path.split('/')[3];
          return jsonResponse({
            'messages': [
              {
                ...messageJson(
                  id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
                  match: id,
                  sender: testUser,
                  content: 'Et toi, tu lis quoi en ce moment ?',
                ),
                'created_at': clock
                    .subtract(const Duration(days: 23, hours: 23, minutes: 59))
                    .toIso8601String(),
              },
              {
                ...messageJson(
                  match: id,
                  sender: candidateTwo,
                  content: 'Et si on passait à cette librairie samedi ?',
                  readAt: clock
                      .subtract(const Duration(days: 24))
                      .toIso8601String(),
                ),
                'created_at': clock
                    .subtract(const Duration(days: 24))
                    .toIso8601String(),
              },
              {
                ...messageJson(
                  id: outgoingId,
                  match: id,
                  sender: testUser,
                  content: 'Avec plaisir ! Je te raconterai le roman que je viens de terminer.',
                  readAt: clock
                      .subtract(const Duration(days: 24))
                      .toIso8601String(),
                ),
                'created_at': clock
                    .subtract(const Duration(days: 24, minutes: 5))
                    .toIso8601String(),
              },
            ],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(request);
      });
      await session.establish(testTokens);
      final locale = LocaleController();
      await locale.select('fr');
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: Stack(
            fit: StackFit.expand,
            textDirection: TextDirection.ltr,
            children: [
              HistaeApp(sessionController: session, localeController: locale),
              const Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Text(
                  'Démonstration · profils fictifs',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Color(0xffc6c1d3),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/histae-signature-dark.png'),
          tester.element(find.byType(HistaeApp)),
        ),
      );
      await tester.pump();
      await _capture(tester, 'feed');
      await tester.tap(find.byKey(const Key('feed-reading-settings')));
      await tester.pumpAndSettle();
      await _capture(tester, 'reading');
      await tester.tap(find.byKey(const Key('reading-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-tab-matches')));
      await tester.pumpAndSettle();
      await _capture(tester, 'matches');
      final creditsToggle = find.byKey(const Key('matches-credits-toggle'));
      await tester.tap(creditsToggle);
      await tester.pumpAndSettle();
      await _capture(tester, 'matches-credits');
      await tester.tap(creditsToggle);
      await tester.pumpAndSettle();
      expect(find.text('Archivage et suppression'), findsNothing);
      await tester.tap(find.byKey(const Key('matches-archives')));
      await tester.pumpAndSettle();
      await _capture(tester, 'archives');
      await tester.enterText(
        find.byKey(const Key('archives-search')),
        'camille',
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'archives-search');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('matches-search')),
        'camille',
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'archived-search');
      final card = find.byType(MatchPreviewCard);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await _capture(tester, 'conversation');
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      await _capture(tester, 'conversation-details');
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          'Avec plaisir ! Je te raconterai le roman que je viens de terminer.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await _capture(tester, 'message-date');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-help')),
        450,
        scrollable: find
            .descendant(
              of: find.byType(ProfilePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'profile-actions');
      await tester.tap(find.byKey(const Key('profile-help')));
      await tester.pumpAndSettle();
      final policy = find.text('Archivage et suppression');
      await tester.scrollUntilVisible(
        policy,
        180,
        scrollable: find
            .descendant(
              of: find.byType(HelpPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(policy);
      await tester.pumpAndSettle();
      await _capture(tester, 'archive-policy');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
