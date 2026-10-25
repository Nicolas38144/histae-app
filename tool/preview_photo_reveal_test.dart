// Real Flutter screens, synthetic accounts and an explicitly supplied fictional
// portrait. No real API/storage traffic and no native privacy changes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/matches_fixture.dart';

const _output = 'build/previews/photo-reveal';
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
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        final item = publicMatchJson();
        return jsonResponse({
          'matches': [
            {
              ...item,
              'my_revealed': mine,
              'photos_revealed': mine && partner,
              'unread_count': 0,
              'other_user': {
                ...item['other_user'] as Map,
                'firstname': 'Léa',
                'age': 29,
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
      if (r.url.path == '/api/matches/$testMatch/messages' &&
          r.method == 'GET') {
        return jsonResponse({
          'messages': [
            messageJson(
              content: 'Ça me ferait plaisir de mettre un visage sur nos discussions.',
              readAt: DateTime.now().toUtc().toIso8601String(),
            ),
            messageJson(
              id: outgoingId,
              sender: testUser,
              content: 'Et moi qui pensais être le seul à finir un roman dans le train !',
              readAt: DateTime.now().toUtc().toIso8601String(),
            ),
          ],
          'next_cursor': null,
        });
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
      for (var i = 0; i < (seconds * 15).round(); i++) {
        await tester.pump(const Duration(microseconds: 66667));
        await capture(
          '$_output/frames/${(frame++).toString().padLeft(4, '0')}.png',
        );
      }
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      touch.value = tester.getCenter(finder);
      await record(0.2);
      await tester.tap(finder);
      await record(0.35);
      touch.value = null;
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
        await record(1);
        await tap(find.text('Léa, 29'));
        await record(2);
        await capture('$_output/conversation-before.png', ratio: 2);
        final controller = tester
            .widget<ChatPage>(find.byType(ChatPage))
            .controller;
        // The fixture uses finite HTTP responses rather than a live SSE stream.
        // Stop its reconnect loop and explicitly deliver the simulated update.
        controller.setRealtimeEnabled(false);
        await controller.refresh();
        await tester.pumpAndSettle();
        await tap(find.text('Dévoiler nos photos'));
        await record(2);
        await capture('$_output/invitation.png', ratio: 2);
        await tap(find.text('Dévoiler nos photos').last);
        await record(2.5);
        await capture('$_output/consent.png', ratio: 2);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tap(find.text('Donner mon accord'));
        await record(2);
        await capture('$_output/waiting.png', ratio: 2);
        partner = true;
        await controller.refresh();
        await record(2);
        await capture('$_output/mutual.png', ratio: 2);
        await tap(find.text('Voir sa photo'));
        await record(2.5);
        expect(find.byType(PartnerPhotoPage), findsOneWidget);
        await capture('$_output/discovered.png', ratio: 2);
        await tap(find.byTooltip('Retour'));
        await record(0.6);
        await tap(find.byTooltip('Retour'));
        await record(1.2);
        await capture('$_output/conversation-after.png', ratio: 2);
        await tap(find.byTooltip('Retour'));
        await record(1.2);
        await capture('$_output/matches-after.png', ratio: 2);
        await tap(find.text('Léa, 29'));
        await record(0.6);
        await tap(find.text('Nos photos'));
        await record(0.6);
        await tap(find.text('Retirer mon accord'));
        await record(1.5);
        await tap(find.text('Retirer mon accord').last);
        await record(1.5);
        await capture('$_output/withdrawn.png', ratio: 2);
        await tap(find.byTooltip('Retour'));
        await record(0.6);
        await tap(find.byTooltip('Retour'));
        await record(1);
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
    touch.dispose();
    // HistaeApp owns the injected controllers and disposes them on unmount.
  }, timeout: const Timeout(Duration(minutes: 8)));
}
