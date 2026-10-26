// Real Flutter screens, synthetic accounts and an explicitly supplied fictional
// portrait. No real API/storage traffic and no native privacy changes.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/matches_fixture.dart';

const _output = String.fromEnvironment(
  'PHOTO_PREVIEW_OUTPUT',
  defaultValue: 'build/previews/photo-reveal',
);
const _extended = bool.fromEnvironment('PHOTO_PREVIEW_LONG');
const _receiptsOnly = bool.fromEnvironment('PHOTO_PREVIEW_RECEIPTS_ONLY');
const _boundary = Key('photo-reveal-preview');

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

  testWidgets('record opening, mutual reveal and withdrawal', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 28);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final portrait = (await tester.runAsync(
      () => File(
        const String.fromEnvironment(
          'PHOTO_PREVIEW_PORTRAIT',
          defaultValue: 'pictures/previews/photo-reveal-2026-10-25/fictional-portrait.png',
        ),
      ).readAsBytes(),
    ))!;
    var mine = false, partner = false;
    final writes = <String>[];
    final started = DateTime.now().toUtc().subtract(
      const Duration(minutes: 20),
    );
    final thread = <Map<String, dynamic>>[
      {
        ...messageJson(
          content:
              'Ça me ferait plaisir de mettre un visage sur nos discussions.',
          readAt: started.add(const Duration(minutes: 19)).toIso8601String(),
        ),
        'created_at': started
            .add(const Duration(minutes: 18))
            .toIso8601String(),
      },
      {
        ...messageJson(
          id: outgoingId,
          sender: testUser,
          content: 'Et moi qui pensais être le seul à finir un roman dans le train !',
          readAt: started.add(const Duration(minutes: 17)).toIso8601String(),
        ),
        'created_at': started
            .add(const Duration(minutes: 16))
            .toIso8601String(),
      },
    ];

    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        final item = publicMatchJson();
        return jsonResponse({
          'matches': [
            {
              ...item,
              'created_at': started.toIso8601String(),
              'expires_at': started
                  .add(const Duration(days: 1))
                  .toIso8601String(),
              'last_message': thread.first,
              'my_revealed': mine,
              'photos_revealed': mine && partner,
              'unread_count': 0,
              'other_user': {
                ...item['other_user'] as Map,
                'firstname': 'Léa',
                'age': 29,
                'bio':
                    'Je vis avec des livres sur toutes les surfaces et une liste de '
                    'balades qui grandit plus vite que je ne la coche. Le samedi, '
                    'je pars souvent acheter du pain et je rentre deux heures plus tard : '
                    'un café en terrasse, une librairie ouverte, quelqu’un avec qui '
                    'la conversation a continué.\n\n'
                    'J’aimerais rencontrer une personne avec qui on peut parler '
                    'longtemps, mais aussi se taire sans chercher à remplir le vide. '
                    'Je cuisine assez bien les plats qui demandent de la patience ; '
                    'pour les desserts, mieux vaut prévoir une boulangerie pas loin.',
                'photo': mine && partner
                    ? 'https://photos.example/fictional-portrait'
                    : null,
              },
            },
          ],
          'next_cursor': null,
        });
      }
      if (r.url.path.endsWith('/reveal')) {
        writes.add(r.method);
        mine = r.method == 'PATCH';
        return jsonResponse({'photos_revealed': mine && partner});
      }
      if (r.url.path == '/api/matches/$testMatch/messages') {
        if (r.method == 'POST') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          final message = {
            ...messageJson(
              id: '12121212-1212-4212-8212-121212121212',
              sender: testUser,
              content: body['content'] as String,
            ),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };
          thread.insert(0, message);
          return jsonResponse(message, 201);
        }
        return jsonResponse({'messages': thread, 'next_cursor': null});
      }
      return defaultContinuationResponse(r);
    });
    await session.establish(testTokens);
    final locale = LocaleController();
    await locale.select('fr');
    final touch = ValueNotifier<Offset?>(null);
    var frame = 0;
    Future<void> capture(String path, {double ratio = 1.5}) async {
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: ratio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    Future<void> record(double seconds) async {
      if (_receiptsOnly) {
        await tester.pump(Duration(microseconds: (seconds * 1000000).round()));
        await tester.pumpAndSettle();
        return;
      }
      for (var i = 0; i < (seconds * 15).round(); i++) {
        await tester.pump(const Duration(microseconds: 66667));
        await capture(
          '$_output/frames/${(frame++).toString().padLeft(4, '0')}.png',
        );
      }
    }

    Future<void> hold(double seconds) => record(seconds * (_extended ? 2 : 1));

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      touch.value = tester.getCenter(finder);
      await record(0.2);
      await tester.tap(finder);
      await record(0.35);
      touch.value = null;
    }

    Future<void> profileTour(String name, {required bool revealed}) async {
      await tap(find.byTooltip('Voir son profil'));
      await hold(2.5);
      expect(
        find.byType(PartnerPhoto),
        revealed ? findsOneWidget : findsNothing,
      );
      await capture('$_output/profile-$name.png', ratio: 2);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -650));
      await record(0.8);
      await hold(2);
      await capture('$_output/profile-$name-text.png', ratio: 2);
      await tap(find.byTooltip('Retour'));
      await hold(0.6);
    }

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: _boundary,
            child: Stack(
              textDirection: TextDirection.ltr,
              fit: StackFit.expand,
              children: [
                HistaeApp(localeController: locale, sessionController: session),
                const Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Text(
                      'DÉMONSTRATION · PROFILS FICTIFS',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        color: Color(0xFFAFAAB9),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<Offset?>(
                  valueListenable: touch,
                  builder: (_, point, _) => point == null
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: point.dx - 15,
                          top: point.dy - 15,
                          child: IgnorePointer(
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Matchs').last);
        await tester.pumpAndSettle();
        final controller = tester
            .widget<MatchesPage>(find.byType(MatchesPage))
            .controller;
        // The fixture uses finite HTTP responses rather than a live SSE stream.
        // Stop its reconnect loop and explicitly deliver simulated updates.
        controller.setRealtimeEnabled(false);
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(find.textContaining('La connexion reprend'), findsNothing);
        await hold(1);
        if (_extended) {
          await tap(find.text('Voir mes crédits'));
          await hold(3);
          await capture('$_output/credits.png', ratio: 2);
          await tap(find.byTooltip('Retour'));
          await hold(1);
        }
        await tap(find.text('Léa, 29'));
        await hold(2);
        await capture('$_output/conversation-before.png', ratio: 2);
        if (_receiptsOnly) {
          const answer = 'Oui, ça me ferait plaisir. On se les dévoile ?';
          await tester.enterText(find.byType(TextField), answer);
          await tap(find.text('Envoyer'));
          FocusManager.instance.primaryFocus?.unfocus();
          await record(0.4);
          await capture('$_output/message-sent.png', ratio: 2);
          await tap(find.text(answer));
          await record(0.1);
          await capture('$_output/message-date.png', ratio: 2);
          await record(3.1);
          await capture('$_output/message-date-hidden.png', ratio: 2);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        expect(
          find.textContaining('Fin de la première période le'),
          findsNothing,
        );
        if (_extended) {
          await tap(find.byTooltip('État de la conversation'));
          await hold(3);
          expect(
            find.textContaining('Fin de la première période le'),
            findsOneWidget,
          );
          await capture('$_output/details.png', ratio: 2);
          await tap(find.text('Fermer'));
          await hold(1);
          await profileTour('private', revealed: false);
          const answer = 'Oui, ça me ferait plaisir. On se les dévoile ?';
          await tap(find.byType(TextField));
          for (var end = 5; end < answer.length; end += 5) {
            await tester.enterText(
              find.byType(TextField),
              answer.substring(0, end),
            );
            await record(0.2);
          }
          await tester.enterText(find.byType(TextField), answer);
          await hold(1);
          await tap(find.text('Envoyer'));
          FocusManager.instance.primaryFocus?.unfocus();
          await hold(2);
          expect(thread.first['content'], answer);
          await capture('$_output/message-sent.png', ratio: 2);
        }
        await tap(find.text('Dévoiler nos photos'));
        await hold(2);
        await capture('$_output/invitation.png', ratio: 2);
        await tap(find.text('Dévoiler nos photos').last);
        await hold(2.5);
        await capture('$_output/consent.png', ratio: 2);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tap(find.text('Donner mon accord'));
        await hold(2);
        await capture('$_output/waiting.png', ratio: 2);
        partner = true;
        await controller.refresh();
        await hold(2);
        await capture('$_output/mutual.png', ratio: 2);
        if (_extended) {
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -850),
          );
          await record(1);
          await hold(2);
          await capture('$_output/actions-spacing.png', ratio: 2);
          await tester.drag(find.byType(Scrollable).last, const Offset(0, 850));
          await record(1);
        }
        await tap(find.text('Voir sa photo'));
        await hold(2.5);
        expect(find.byType(PartnerPhotoPage), findsOneWidget);
        await capture('$_output/discovered.png', ratio: 2);
        await tap(find.byTooltip('Retour'));
        await hold(0.6);
        await tap(find.byTooltip('Retour'));
        await hold(1.2);
        await capture('$_output/conversation-after.png', ratio: 2);
        if (_extended) await profileTour('revealed', revealed: true);
        await tap(find.byTooltip('Retour'));
        await hold(1.2);
        await capture('$_output/matches-after.png', ratio: 2);
        await tap(find.text('Léa, 29'));
        await hold(0.6);
        await tap(find.text('Nos photos'));
        await hold(0.6);
        await tap(find.text('Retirer mon accord'));
        await hold(1.5);
        await tap(find.text('Retirer mon accord').last);
        await hold(1.5);
        await capture('$_output/withdrawn.png', ratio: 2);
        await tap(find.byTooltip('Retour'));
        await hold(0.6);
        if (_extended) await profileTour('withdrawn', revealed: false);
        await tap(find.byTooltip('Retour'));
        await hold(1);
        expect(writes, ['PATCH', 'DELETE']);
        await capture('$_output/matches-withdrawn.png', ratio: 2);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((r) async {
        expect(r.url.host, 'photos.example');
        expect(
          r.headers.keys.map((v) => v.toLowerCase()),
          isNot(contains('authorization')),
        );
        return http.Response.bytes(portrait, 200);
      }),
    );
    await tester.runAsync(
      () => File('$_output/recording.json').writeAsString(
        jsonEncode({
          'frames': frame,
          'capture_fps': 15,
          'duration_seconds': frame / 15,
          'extended': _extended,
          'receipts_only': _receiptsOnly,
        }),
      ),
    );
    touch.dispose();
    // HistaeApp owns the injected controllers and disposes them on unmount.
  }, timeout: const Timeout(Duration(minutes: 8)));
}
