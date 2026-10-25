// Render the real feed with synthetic data, without production API requests.
// flutter test tool/preview_feed_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/discovery_fixture.dart';

const _biography =
    'Je suis le genre de personne qui entre dans une librairie '
    'pour cinq minutes et en ressort une heure plus tard. J’aime '
    'les romans dont on reparle longtemps, les cafés qui deviennent '
    'des habitudes et les promenades où l’on change trois fois '
    'de direction.\n\n'
    'En semaine, je cuisine pour mes amis, même quand la recette '
    'part un peu de travers. Le dimanche, vous me trouverez souvent '
    'sur un sentier, un appareil photo dans le sac et quelque chose '
    'à partager pour le goûter.\n\n'
    'J’aimerais rencontrer quelqu’un de curieux, avec qui passer '
    'des discussions très sérieuses aux blagues les plus absurdes. '
    'Racontez-moi un endroit où vous retournez toujours, ou le petit '
    'projet qui vous occupe en ce moment. Je préfère une réponse '
    'sincère à une phrase parfaite.';

Future<void> _capture(WidgetTester tester, String path) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('feed-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

Future<void> _loadBrand(WidgetTester tester) async {
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/branding/histae-signature-dark.png'),
      tester.element(find.byType(HistaeApp)),
    ),
  );
  await tester.pump();
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

  testWidgets('capture a populated feed with a long biography', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = testSession((request) async {
      if (request.url.path == '/api/feed') {
        return jsonResponse({
          'profiles': [candidateJson(candidateOne, bio: _biography)],
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
        key: const Key('feed-preview'),
        child: HistaeApp(localeController: locale, sessionController: session),
      ),
    );
    await tester.pumpAndSettle();
    await _loadBrand(tester);
    expect(find.text('Léa, 27'), findsOneWidget);
    await _capture(tester, 'build/previews/feed/feed-filled.png');
    await tester.drag(
      find.byKey(const Key('feed-profile-scroll')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'build/previews/feed/feed-filled-actions.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'record like and pass with real gestures and vertical transitions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final decision in ['like', 'pass']) {
        const onlyAction = String.fromEnvironment('FEED_PREVIEW_ACTION');
        if (onlyAction.isNotEmpty && decision != onlyAction) continue;
        final writes = <String>[];
        final session = testSession((request) async {
          if (request.url.path == '/api/feed') {
            return jsonResponse({
              'profiles': [
                candidateJson(candidateOne, bio: _biography),
                candidateJson(candidateTwo, name: 'Camille', bio: _biography),
              ],
              'next_cursor': null,
            });
          }
          if (request.url.path == '/api/swipes') {
            final action =
                (jsonDecode(request.body) as Map)['decision'] as String;
            writes.add(action);
            await Future<void>.delayed(const Duration(milliseconds: 160));
            return jsonResponse({'decision': action, 'matched': false}, 201);
          }
          return defaultContinuationResponse(request);
        });
        await session.establish(testTokens);
        final locale = LocaleController();
        await locale.select('fr');
        final touch = ValueNotifier<Offset?>(null);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('feed-preview'),
            child: Stack(
              textDirection: TextDirection.ltr,
              fit: StackFit.expand,
              children: [
                HistaeApp(localeController: locale, sessionController: session),
                // Demonstration touch marker only; it is not part of the app UI.
                ValueListenableBuilder(
                  valueListenable: touch,
                  builder: (_, point, _) => point == null
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: point.dx - 19,
                          top: point.dy - 19,
                          child: IgnorePointer(
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0x44F9F7F2),
                                border: Border.all(
                                  color: const Color(0xFFF9F7F2),
                                  width: 2,
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
        // Finish the opening before recording the feed's reading delay.
        await tester.pump(const Duration(milliseconds: 1600));
        await _loadBrand(tester);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.text('Léa, 27'), findsOneWidget);
        expect(find.byKey(const Key('app-opening')), findsNothing);
        var index = 0;
        Future<void> frame([int count = 1]) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(microseconds: 33334));
            await _capture(
              tester,
              'build/previews/feed/$decision-frames/'
              '${(index++).toString().padLeft(4, '0')}.png',
            );
          }
        }

        if (decision == 'like') {
          await frame(94);
          final point = tester.getCenter(find.text('Léa, 27'));
          touch.value = point;
          await tester.tapAt(point);
          await frame(2);
          touch.value = null;
          await frame(1);
          touch.value = point;
          await tester.tapAt(point);
          await frame(2);
          touch.value = null;
        } else {
          await frame(36);
          final scroll = find.byKey(const Key('feed-profile-scroll'));
          final position = tester
              .state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)),
              )
              .position;
          final stepDistance = (position.maxScrollExtent + 120) / 48;
          for (var stroke = 0; stroke < 3; stroke++) {
            var point = tester.getCenter(scroll) + const Offset(0, 200);
            final reading = await tester.startGesture(point);
            for (var step = 0; step < 16; step++) {
              point += Offset(0, -stepDistance);
              touch.value = point;
              await reading.moveBy(Offset(0, -stepDistance));
              await frame();
            }
            await reading.up();
          }
          touch.value = null;
          await frame(16);
          if (position.extentAfter > 0.5) {
            var point = tester.getCenter(scroll) + const Offset(0, 150);
            final finishReading = await tester.startGesture(point);
            for (var step = 0; step < 8; step++) {
              point += const Offset(0, -24);
              touch.value = point;
              await finishReading.moveBy(const Offset(0, -24));
              await frame();
            }
            await finishReading.up();
            touch.value = null;
            await frame(8);
          }
          expect(position.extentAfter, closeTo(0, 0.5));
          var point = tester.getCenter(scroll) + const Offset(0, 150);
          final passing = await tester.startGesture(point);
          for (var step = 0; step < 8; step++) {
            point += const Offset(0, -24);
            touch.value = point;
            await passing.moveBy(const Offset(0, -24));
            await frame();
          }
          await passing.up();
          touch.value = null;
        }
        await frame(55);
        expect(writes, [decision]);
        expect(find.text('Camille, 27'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        touch.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
