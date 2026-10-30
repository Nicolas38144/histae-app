// Actual widgets; synthetic sessions, message acknowledgements and store data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/updates/application/store_update_controller.dart';
import 'package:histae_app/features/updates/data/store_update_gateway.dart';
import 'package:histae_app/features/updates/presentation/store_update_gate.dart';
import 'package:http/http.dart' as http;

import '../test/support/auth_fixture.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/store_update_fixture.dart';

const _output = 'build/previews/message-queue-2026-10-30';
const _boundary = Key('message-queue-preview');

Future<void> capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_output/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
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

  testWidgets(
    'capture pending dots, confirmed receipts, limit hint and required update',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final responses = [
        Completer<http.Response>(),
        Completer<http.Response>(),
      ];
      var posts = 0;
      final sent = <Object?>[];
      final session = testSession((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          final response = await responses[posts++].future;
          sent.insert(0, jsonDecode(response.body));
          return response;
        }
        if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
          return jsonResponse({
            'messages': [
              ...sent,
              messageJson(
                content: 'Tu me raconteras la suite demain ?',
                readAt: DateTime.now().toUtc().toIso8601String(),
              ),
              messageJson(
                id: outgoingId,
                sender: testUser,
                content: 'Avec plaisir !',
                readAt: DateTime.now().toUtc().toIso8601String(),
              ),
            ],
            'next_cursor': null,
          });
        }
        return defaultMatchesResponse(request);
      });
      await session.establish(testTokens);
      final matches = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      final store = FakeStoreUpdateGateway();
      final updates = StoreUpdateController(store);
      final navigator = GlobalKey<NavigatorState>();
      await matches.activate();
      await matches.openChat(testMatch);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: histaeTheme(Brightness.dark),
            locale: const Locale('fr'),
            localizationsDelegates: AppMessages.localizationsDelegates,
            supportedLocales: AppMessages.supportedLocales,
            builder: (context, child) => Stack(
              fit: StackFit.expand,
              children: [
                StoreUpdateGate(controller: updates, child: child!),
                const Positioned(
                  top: 3,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Démonstration · données fictives',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xffc6c1d3),
                    ),
                  ),
                ),
              ],
            ),
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ChatPage(controller: matches, matchId: testMatch),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final composer = find.byKey(const Key('chat-composer'));
      for (final content in [
        'Je te raconte ça demain.',
        'Et je t’envoie le titre du livre.',
      ]) {
        await tester.enterText(composer, content);
        await tester.tap(find.text('Envoyer'));
        await tester.pump(const Duration(milliseconds: 140));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await capture(tester, 'sending');
      responses[0].complete(
        jsonResponse(
          messageJson(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            sender: testUser,
            content: 'Je te raconte ça demain.',
          ),
          201,
        ),
      );
      await tester.pump();
      responses[1].complete(
        jsonResponse(
          messageJson(
            id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            sender: testUser,
            content: 'Et je t’envoie le titre du livre.',
          ),
          201,
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'sent');
      await tester.enterText(composer, List.filled(2000, 'a').join());
      await tester.pump();
      await capture(tester, 'limit');
      store.available = StoreUpdate(
        Uri.https('play.google.com', '/store/apps/details', {
          'id': 'com.histae.histae_app',
        }),
      );
      await updates.check();
      await tester.pumpAndSettle();
      await capture(tester, 'update-required');
      matches.suspend();
      await tester.pumpWidget(const SizedBox.shrink());
      matches.dispose();
      updates.dispose();
      session.dispose();
    },
  );
}
