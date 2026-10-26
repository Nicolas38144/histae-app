import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo_page.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/partner_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';

Widget localized(Widget home, {GlobalKey<NavigatorState>? navigator}) =>
    MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('fr'),
      localizationsDelegates: AppMessages.localizationsDelegates,
      supportedLocales: AppMessages.supportedLocales,
      home: home,
    );

void main() {
  testWidgets(
    'the chat name opens the full cached profile and preserves the draft',
    (tester) async {
      var lists = 0, histories = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') lists++;
        if (r.url.path.endsWith('/messages')) histories++;
        return defaultMatchesResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      addTearDown(c.dispose);
      await c.activate();
      await c.openChat(testMatch);
      final initialLists = lists, initialHistories = histories;
      await tester.pumpWidget(
        localized(ChatPage(controller: c, matchId: testMatch)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Un message en cours');
      await tester.tap(find.text('Léa'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerPage), findsOneWidget);
      expect(find.text('Léa, 27'), findsOneWidget);
      expect(find.text(c.selected!.partner.bio!), findsOneWidget);
      expect(find.text('Curieuse'), findsOneWidget);
      expect(find.text('Votre dimanche idéal ?'), findsOneWidget);
      expect(
        find.text('Un café, un livre et une promenade sans itinéraire.'),
        findsOneWidget,
      );
      expect(find.byType(PartnerPhoto), findsNothing);
      expect(lists, initialLists);
      expect(histories, initialHistories);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Un message en cours',
      );
      expect(
        find.textContaining('Fin de la première période le'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('État de la conversation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Fin de la première période le'),
        findsOneWidget,
      );
      c.suspend();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<MatchesController> revealedMatch() async {
    final session = testSession((r) async {
      if (r.url.path != '/api/matches/me') return defaultMatchesResponse(r);
      final item = publicMatchJson();
      return jsonResponse({
        'matches': [
          {
            ...item,
            'my_revealed': true,
            'photos_revealed': true,
            'other_user': {
              ...item['other_user'] as Map,
              'photo': 'https://photos.example/synthetic',
            },
          },
        ],
        'next_cursor': null,
      });
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    return c;
  }

  final pixels = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLZkAAAAASUVORK5CYII=',
  );

  testWidgets(
    'the profile drops a pending full photo immediately on withdrawal',
    (tester) async {
      final c = await revealedMatch();
      final response = Completer<http.Response>();
      var downloads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            localized(PartnerPage(controller: c, id: testMatch)),
          );
          await tester.pump();
          expect(find.byType(PartnerPhoto), findsOneWidget);
          expect(downloads, 1);
          c.blockPhotos(testMatch);
          await tester.pump();
          expect(find.byType(PartnerPhoto), findsNothing);
          response.complete(http.Response.bytes(pixels, 200));
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsNothing);
          expect(find.text('Léa, 27'), findsOneWidget);
          c.suspend();
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((r) {
          downloads++;
          expect(
            r.headers.keys.map((v) => v.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(r.followRedirects, isFalse);
          return response.future;
        }),
      );
    },
  );

  testWidgets(
    'covering a full photo cancels its display and rejects late bytes',
    (tester) async {
      final c = await revealedMatch();
      final navigator = GlobalKey<NavigatorState>();
      final response = Completer<http.Response>();
      await tester.pumpWidget(
        localized(
          PartnerPhotoPage(
            access: c,
            matchId: testMatch,
            photoClient: () => MockClient((_) => response.future),
          ),
          navigator: navigator,
        ),
      );
      await tester.pump();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      response.complete(http.Response.bytes(pixels, 200));
      await tester.pumpAndSettle();
      expect(find.byType(Image, skipOffstage: false), findsNothing);
      c.suspend();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
