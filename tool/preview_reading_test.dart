// Real Flutter UI with fictional profiles and local stores; no provider calls.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/reading/application/reading_controller.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/discovery_fixture.dart';
import '../test/support/reading_fixture.dart';

const _output = 'build/previews/reading';
const _boundary = Key('reading-demo');
const _bio =
    'Je suis le genre de personne qui entre dans une librairie pour cinq '
    'minutes et en ressort une heure plus tard. J’aime les romans dont on '
    'reparle longtemps, les cafés qui deviennent des habitudes et les '
    'promenades où l’on change trois fois de direction.\n\n'
    'En semaine, je cuisine pour mes amis, même quand la recette part un '
    'peu de travers. Le dimanche, vous me trouverez souvent sur un sentier, '
    'un appareil photo dans le sac et quelque chose à partager pour le goûter.\n\n'
    'J’aimerais rencontrer quelqu’un de curieux, avec qui passer des '
    'discussions très sérieuses aux blagues les plus absurdes. Racontez-moi '
    'un endroit où vous retournez toujours, ou le petit projet qui vous '
    'occupe en ce moment.';

Future<void> _capture(WidgetTester tester, String path) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
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
    final bytes = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  Future<void> show(
    WidgetTester tester, {
    String language = 'fr',
    ValueNotifier<Offset?>? touch,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    final session = testSession((request) async {
      if (request.url.path == '/api/feed') {
        return jsonResponse({
          'profiles': [candidateJson(candidateOne, bio: _bio)],
          'next_cursor': null,
        });
      }
      return defaultDiscoveryResponse(request);
    });
    await session.establish(testTokens);
    final locale = LocaleController();
    await locale.select(language);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Stack(
          textDirection: TextDirection.ltr,
          fit: StackFit.expand,
          children: [
            HistaeApp(
              localeController: locale,
              sessionController: session,
              readingController: ReadingController(store: TestReadingStore()),
            ),
            // Preview label and pointer are absent from the production app.
            const Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Text(
                'Démonstration · profil fictif',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Color(0xffc6c1d3),
                ),
              ),
            ),
            if (touch != null)
              ValueListenableBuilder(
                valueListenable: touch,
                builder: (_, point, _) => point == null
                    ? const SizedBox.shrink()
                    : Positioned(
                        left: point.dx - 17,
                        top: point.dy - 17,
                        child: IgnorePointer(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x33f9f7f2),
                              border: Border.all(
                                color: const Color(0xfff9f7f2),
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
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/histae-signature-dark.png'),
        tester.element(find.byType(HistaeApp)),
      ),
    );
    await tester.pump();
  }

  void cleanupView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('record reading choices in a populated feed', (tester) async {
    cleanupView(tester);
    final touch = ValueNotifier<Offset?>(null);
    await show(tester, touch: touch);
    var index = 0;
    Future<void> frame([int count = 1]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(microseconds: 66667));
        await _capture(
          tester,
          '$_output/frames/${(index++).toString().padLeft(4, '0')}.png',
        );
      }
    }

    Future<void> tap(String key) async {
      final finder = find.byKey(Key(key));
      touch.value = tester.getCenter(finder);
      await frame(2);
      await tester.tap(finder);
      await frame(5);
      touch.value = null;
      await frame(5);
    }

    Future<void> scroll(String key, double distance) async {
      final finder = find.byKey(Key(key));
      final start = tester.getCenter(finder) + const Offset(0, 90);
      final gesture = await tester.startGesture(start);
      var point = start;
      for (var i = 0; i < 12; i++) {
        final delta = Offset(0, distance / 12);
        point += delta;
        touch.value = point;
        await gesture.moveBy(delta);
        await frame();
      }
      await gesture.up();
      touch.value = null;
      await frame(8);
    }

    await _capture(tester, '$_output/feed-default.png');
    await frame(20);
    await tap('feed-reading-settings');
    await frame(18);
    await _capture(tester, '$_output/settings-default.png');
    await tap('reading-size-comfortable');
    await frame(12);
    await tap('reading-spacing-relaxed');
    await frame(16);
    await _capture(tester, '$_output/settings-comfortable.png');
    await tap('reading-close');
    await frame(20);
    await _capture(tester, '$_output/feed-comfortable.png');
    await scroll('feed-profile-scroll', -270);
    await frame(24);
    await tap('feed-reading-settings');
    await frame(12);
    await tap('reading-size-large');
    await tap('reading-spacing-spacious');
    await scroll('reading-settings-scroll', -140);
    await frame(20);
    await _capture(tester, '$_output/settings-large.png');
    await tap('reading-close');
    await frame(22);
    await _capture(tester, '$_output/feed-large.png');
    await tester.pumpWidget(const SizedBox.shrink());
    touch.dispose();
    await tester.runAsync(
      () => File('$_output/recording.json').writeAsString(
        jsonEncode({
          'frames': index,
          'fps': 15,
          'duration': index / 15,
          'content': 'Fictional profile; real Flutter reading settings; no production API calls.',
        }),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
    'review reading settings in every language with system text at 100 and 200 percent',
    (tester) async {
      cleanupView(tester);
      for (final language in ['fr', 'en', 'es', 'it']) {
        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await show(tester, language: language);
          await tester.tap(find.byKey(const Key('feed-reading-settings')));
          await tester.pumpAndSettle();
          final name = '$language-${scale == 1 ? 'normal' : 'large'}';
          await _capture(tester, '$_output/$name-settings.png');
          await tester.ensureVisible(
            find.byKey(const Key('reading-size-large')),
          );
          await tester.tap(find.byKey(const Key('reading-size-large')));
          await tester.pumpAndSettle();
          final scroller = find.descendant(
            of: find.byKey(const Key('reading-settings-scroll')),
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('reading-reset')),
            160,
            scrollable: scroller,
          );
          await tester.pumpAndSettle();
          final previewContext = tester.element(
            find.byKey(const Key('reading-preview-text')),
          );
          expect(MediaQuery.textScalerOf(previewContext).scale(22), 22 * scale);
          await _capture(tester, '$_output/$name-preview.png');
          await tester.tap(find.byKey(const Key('reading-reset')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('reading-close')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const Key('feed-biography')))
                .style!
                .fontSize,
            18,
          );
          await _capture(tester, '$_output/$name-feed.png');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
