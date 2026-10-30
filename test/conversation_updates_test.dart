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
import 'package:histae_app/features/matches/presentation/message_bubble.dart';
import 'package:histae_app/features/matches/presentation/message_metadata.dart';
import 'package:histae_app/features/matches/presentation/message_sending_indicator.dart';
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
  testWidgets(
    'receipts sit outside only the latest sent and latest read bubbles and coalesce after reading',
    (tester) async {
      const unreadOlder = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const readLatest = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      const readOlder = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      var allRead = false;
      final session = testSession((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/messages')) {
          return jsonResponse({
            'messages': [
              messageJson(readAt: DateTime.now().toUtc().toIso8601String()),
              for (final entry in [
                (outgoingId, 'Le plus récent', false),
                (unreadOlder, 'Un autre envoi', false),
                (readLatest, 'Le dernier lu', true),
                (readOlder, 'Un échange plus ancien', true),
              ])
                messageJson(
                  id: entry.$1,
                  sender: testUser,
                  content: entry.$2,
                  readAt: allRead || entry.$3
                      ? DateTime.now().toUtc().toIso8601String()
                      : null,
                ),
            ],
            'next_cursor': null,
          });
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
        await tester.pumpWidget(
          localized(ChatPage(controller: c, matchId: testMatch)),
        );
        await tester.pumpAndSettle();
        final latest = find.byKey(
          const ValueKey('message-receipt-$outgoingId'),
        );
        expect(find.byType(MessageMetadata), findsNWidgets(2));
        expect(latest, findsOneWidget);
        expect(
          find.byKey(const ValueKey('message-receipt-$readLatest')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('message-receipt-$unreadOlder')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('message-receipt-$readOlder')),
          findsNothing,
        );
        final bubble = find.ancestor(
          of: find.text('Le plus récent'),
          matching: find.byType(MessageBubble),
        );
        expect(
          tester.getRect(latest).top,
          greaterThan(tester.getRect(bubble).bottom),
        );
        expect(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(MessageMetadata),
          ),
          findsNothing,
        );
        allRead = true;
        await c.refresh();
        await tester.pumpAndSettle();
        expect(find.byType(MessageMetadata), findsOneWidget);
        expect(latest, findsOneWidget);
        expect(find.text('Lu'), findsOneWidget);
        expect(find.text('Envoyé'), findsNothing);
        c.suspend();
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        c.dispose();
        session.dispose();
      }
    },
  );

  testWidgets(
    'queued sends stay editable, show animated dots and retry only after a real failure',
    (tester) async {
      var response = Completer<http.Response>();
      final writes = <http.Request>[];
      final session = testSession((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
          writes.add(r);
          return response.future;
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
        await tester.pumpWidget(
          localized(ChatPage(controller: c, matchId: testMatch)),
        );
        await tester.pumpAndSettle();
        final text = AppMessages.of(tester.element(find.byType(ChatPage)));
        final composer = find.byKey(const Key('chat-composer'));
        expect(
          tester.widget<TextField>(composer).textCapitalization,
          TextCapitalization.sentences,
        );
        expect(
          tester.widget<TextField>(composer).decoration!.helperText,
          isNull,
        );
        await tester.enterText(composer, 'Bonjour');
        await tester.tap(find.text(text.chatPageSend));
        await tester.pump();
        expect(c.sending, isTrue);
        expect(find.text('Bonjour'), findsOneWidget);
        expect(find.byType(MessageSendingIndicator), findsOneWidget);
        expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
        expect(tester.widget<TextField>(composer).readOnly, isFalse);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, text.chatPageSend),
              )
              .onPressed,
          isNotNull,
        );
        final transform = find
            .descendant(
              of: find.byType(MessageSendingIndicator),
              matching: find.byType(Transform),
            )
            .first;
        final initialTransform = tester
            .widget<Transform>(transform)
            .transform
            .clone();
        await tester.pump(const Duration(milliseconds: 160));
        expect(
          tester.widget<Transform>(transform).transform,
          isNot(initialTransform),
        );
        await tester.enterText(composer, 'La suite');
        await tester.tap(find.text(text.chatPageSend));
        await tester.pump();
        expect(c.pendingMessageCount, 2);
        expect(writes, hasLength(1));
        expect(find.text('La suite'), findsOneWidget);
        await tester.enterText(composer, 'Mon prochain brouillon');
        response.completeError(http.ClientException('Synthetic response loss'));
        await tester.pumpAndSettle();
        expect(c.sendFailure, isNotNull);
        expect(find.text(text.appStringsTryAgain), findsOneWidget);
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'Mon prochain brouillon',
        );
        final key = c.pendingMessage!.key;
        response = Completer<http.Response>();
        await tester.tap(find.text(text.appStringsTryAgain));
        await tester.pump();
        expect(c.pendingMessage!.key, key);
        expect(writes, hasLength(2));
        expect(writes.first.headers['idempotency-key'], key);
        expect(writes[1].headers['idempotency-key'], key);
        expect(writes[1].body, writes[0].body);
        final second = Completer<http.Response>();
        response.complete(
          jsonResponse(
            messageJson(id: outgoingId, sender: testUser, content: 'Bonjour'),
            201,
          ),
        );
        response = second;
        await tester.pump();
        expect(writes, hasLength(3));
        expect(c.pendingMessageCount, 1);
        expect(c.messages.where((m) => m.id == outgoingId), hasLength(1));
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'Mon prochain brouillon',
        );
        second.complete(
          jsonResponse(
            messageJson(
              id: '99999999-9999-4999-8999-999999999999',
              sender: testUser,
              content: 'La suite',
            ),
            201,
          ),
        );
        await tester.pump();
        expect(c.pendingMessageCount, 0);
        expect(find.byType(MessageSendingIndicator), findsNothing);
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'Mon prochain brouillon',
        );
        await tester.enterText(composer, List.filled(2000, '🌿').join());
        await tester.pump();
        expect(
          tester.widget<TextField>(composer).decoration!.helperText,
          text.chatPageMessageLimitReached,
        );
        await tester.enterText(composer, 'Un texte court');
        await tester.pump();
        expect(
          tester.widget<TextField>(composer).decoration!.helperText,
          isNull,
        );
        c.suspend();
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        c.dispose();
        session.dispose();
      }
    },
  );

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
