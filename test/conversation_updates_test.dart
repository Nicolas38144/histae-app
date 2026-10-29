import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

Widget localized(Widget home) => MaterialApp(
  theme: histaeTheme(Brightness.dark),
  locale: const Locale('fr'),
  localizationsDelegates: AppMessages.localizationsDelegates,
  supportedLocales: AppMessages.supportedLocales,
  home: home,
);

void main() {
  testWidgets('a send finishing during a history read is retained', (
    tester,
  ) async {
    Completer<http.Response>? history;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/messages') &&
          r.method == 'GET' &&
          history != null) {
        return history.future;
      }
      if (r.url.path.endsWith('/messages') && r.method == 'POST') {
        return jsonResponse(
          messageJson(id: outgoingId, sender: testUser, content: 'À bientôt'),
          201,
        );
      }
      return defaultMatchesResponse(r);
    });
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    try {
      await c.activate();
      await c.openChat(testMatch);
      history = Completer<http.Response>();
      final refresh = c.refreshPhotos();
      await tester.pump();
      await c.send('À bientôt');
      expect(c.messages.any((m) => m.id == outgoingId), isTrue);
      history.complete(
        jsonResponse({
          'messages': [messageJson()],
          'next_cursor': null,
        }),
      );
      await refresh;
      expect(c.messages.any((m) => m.id == outgoingId), isTrue);
      expect(c.pendingMessage, isNull);
    } finally {
      c.dispose();
      session.dispose();
    }
  });

  testWidgets(
    'credits start collapsed below the matches and expanding uses no API',
    (tester) async {
      var requests = 0;
      final session = testSession((r) async {
        requests++;
        return defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(localized(MatchesPage(controller: c)));
      await tester.pumpAndSettle();
      final credits = find.byKey(const Key('matches-credits-toggle'));
      expect(
        tester.getRect(find.byType(MatchPreviewCard)).bottom,
        lessThan(tester.getRect(credits).top),
      );
      expect(tester.getSize(credits).height, lessThan(80));
      expect(find.byKey(const Key('free-credits-remaining')), findsNothing);
      final reads = requests;
      await tester.tap(credits);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('free-credits-remaining')), findsOneWidget);
      expect(find.byKey(const Key('open-videos')), findsOneWidget);
      expect(requests, reads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'messages and receipts update silently without losing keyboard, selection or composing text',
    (tester) async {
      Completer<http.Response>? pending;
      var read = false, received = false;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me' && pending != null) {
          return pending.future;
        }
        if (r.url.path.endsWith('/messages')) {
          return jsonResponse({
            'messages': [
              if (received)
                messageJson(readAt: DateTime.now().toUtc().toIso8601String()),
              messageJson(
                id: outgoingId,
                sender: testUser,
                content: 'Un premier message',
                readAt: read ? DateTime.now().toUtc().toIso8601String() : null,
              ),
            ],
            'next_cursor': null,
          });
        }
        return defaultMatchesResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final realtime = QuietRealtime(session);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: realtime,
      );
      addTearDown(c.dispose);
      await c.activate();
      await c.openChat(testMatch);
      await tester.pumpWidget(
        localized(ChatPage(controller: c, matchId: testMatch)),
      );
      await tester.pumpAndSettle();
      final composer = find.byKey(const Key('chat-composer'));
      await tester.showKeyboard(composer);
      final controller = tester.widget<TextField>(composer).controller!;
      const editing = TextEditingValue(
        text: 'Un brouillon en cours',
        selection: TextSelection.collapsed(offset: 10),
        composing: TextRange(start: 3, end: 12),
      );
      c.setDraft(testMatch, editing.text);
      controller.value = editing;
      await tester.pump();
      final editable = find.descendant(
        of: composer,
        matching: find.byType(EditableText),
      );
      final editor = tester.state<EditableTextState>(editable);

      for (final type in ['message.created', 'message.read']) {
        pending = Completer<http.Response>();
        realtime.emit(MobileSignal(type, matchId: testMatch));
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.listLoading, isTrue);
        expect(c.showLoading, isFalse);
        expect(c.canSend, isTrue);
        expect(tester.widget<TextField>(composer).readOnly, isFalse);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(editor.widget.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(controller.value, editing);
        received = true;
        read = type == 'message.read';
        pending.complete(
          defaultMatchesResponse(
            http.Request('GET', Uri.https('api.example', '/api/matches/me')),
          ),
        );
        pending = null;
        await tester.pumpAndSettle();
        expect(tester.state<EditableTextState>(editable), same(editor));
        expect(controller.value, editing);
        expect(editor.widget.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      }
      expect(find.text('Lu'), findsOneWidget);
      expect(c.messages.length, 2);
      c.suspend();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unread count sits directly below the arrow and disappears at zero',
    (tester) async {
      Widget card(int unread) => localized(
        Scaffold(
          body: ListView(
            children: [
              MatchPreviewCard(
                match: UserMatch.fromJson({
                  ...publicMatchJson(),
                  'unread_count': unread,
                }, testUser),
                ownerId: testUser,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(card(4));
      final badge = find.byKey(const ValueKey('match-unread-$testMatch'));
      expect(
        find.descendant(of: badge, matching: find.text('4')),
        findsOneWidget,
      );
      final bounds = tester.getRect(find.byType(MatchPreviewCard));
      final number = tester.getRect(badge);
      final arrow = tester.getRect(find.byIcon(Icons.arrow_forward_rounded));
      expect(number.center.dx, greaterThan(bounds.center.dx));
      expect(number.center.dx, closeTo(arrow.center.dx, .1));
      expect(number.top - arrow.bottom, closeTo(6, .1));
      await tester.pumpWidget(card(0));
      expect(badge, findsNothing);
    },
  );
}
