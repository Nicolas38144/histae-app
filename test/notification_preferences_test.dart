import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/notifications/application/notification_setting_controller.dart';
import 'package:histae_app/features/notifications/data/notification_preferences.dart';
import 'package:histae_app/features/notifications/data/notification_preferences_repository.dart';
import 'package:histae_app/features/notifications/presentation/conversation_notification_sheet.dart';
import 'package:histae_app/features/notifications/presentation/notification_preferences_panel.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';

Map<String, Object> preferencesJson() => {
  for (final category in NotificationCategory.values) category.key: true,
  'discreet': false,
};
const accountPath = '/api/users/me/notification-preferences';
const mutePath = '/api/matches/$testMatch/notification-preferences';

void main() {
  test(
    'partial writes preserve other choices and invalidate the prior snapshot',
    () async {
      final stored = preferencesJson();
      var reads = 0;
      final writes = <Object?>[];
      final session = testSession((r) async {
        if (r.url.path != accountPath) return defaultMatchesResponse(r);
        if (r.method == 'PATCH') {
          final change = jsonDecode(r.body) as Map<String, dynamic>;
          writes.add(change);
          stored.addAll(change.cast<String, Object>());
        } else {
          reads++;
        }
        return jsonResponse(stored);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final repository = NotificationPreferencesRepository(session);
      final scope = RequestCancellation();
      await repository.account(scope);
      await repository.account(scope);
      expect(reads, 1);
      await repository.changeAccount({'photos': false}, scope);
      final actual = await repository.account(scope);
      expect(writes, [
        {'photos': false},
      ]);
      expect(reads, 2);
      expect(actual.categories[NotificationCategory.photos], false);
      expect(actual.categories[NotificationCategory.messages], true);
    },
  );

  test('a lost write response rereads the server instead of claiming the old choice', () async {
    final stored = preferencesJson();
    var reads = 0;
    final session = testSession((r) async {
      if (r.url.path != accountPath) return defaultMatchesResponse(r);
      if (r.method == 'PATCH') {
        stored['discreet'] = true;
        throw http.ClientException('Synthetic interrupted response');
      }
      reads++;
      return jsonResponse(stored);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final repository = NotificationPreferencesRepository(session);
    final c = NotificationSettingController<NotificationPreferences>(
      session: session,
      read: (scope, policy) => repository.account(scope, policy: policy),
    );
    addTearDown(c.dispose);
    await c.load();
    await c.change(
      (scope) => repository.changeAccount({'discreet': true}, scope),
    );
    expect(reads, 2);
    expect(c.value?.discreet, true);
    expect(c.failure?.kind, ApiFailureKind.network);
    expect(c.busy, false);
  });

  test(
    'logout cancels pending private settings and prevents late repopulation',
    () async {
      final reply = Completer<http.Response>();
      final session = testSession(
        (r) async => r.url.path == accountPath
            ? reply.future
            : defaultMatchesResponse(r),
      );
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final repository = NotificationPreferencesRepository(session);
      final c = NotificationSettingController<NotificationPreferences>(
        session: session,
        read: (scope, policy) => repository.account(scope, policy: policy),
      );
      addTearDown(c.dispose);
      final load = c.load();
      await session.logout();
      reply.complete(jsonResponse(preferencesJson()));
      await load;
      expect(c.value, isNull);
      expect(c.accessible, false);
      expect(c.busy, false);
    },
  );

  test('rate limits prevent repeat writes and unsafe default values stay unavailable', () async {
    var writes = 0;
    final session = testSession((r) async {
      if (r.url.path != accountPath) return defaultMatchesResponse(r);
      if (r.method == 'PATCH') {
        writes++;
        return apiError(429, 'rate_limited', retryAfter: '60');
      }
      return jsonResponse(preferencesJson());
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final repository = NotificationPreferencesRepository(session);
    final c = NotificationSettingController<NotificationPreferences>(
      session: session,
      read: (scope, policy) => repository.account(scope, policy: policy),
    );
    addTearDown(c.dispose);
    await c.load();
    await c.change(
      (scope) => repository.changeAccount({'messages': false}, scope),
    );
    expect(c.retrySeconds, greaterThan(0));
    expect(c.value, isNull);
    await c.change(
      (scope) => repository.changeAccount({'messages': true}, scope),
    );
    expect(writes, 1);
  });

  test(
    'expired mutes are inactive and unmuting sends an explicit null expiry',
    () async {
      final bodies = <Object?>[];
      final session = testSession((r) async {
        if (r.url.path != mutePath) return defaultMatchesResponse(r);
        bodies.add(jsonDecode(r.body));
        return jsonResponse({'muted': false, 'muted_until': null});
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final repository = NotificationPreferencesRepository(session);
      await repository.mute(testMatch, RequestCancellation(), muted: false);
      expect(bodies, [
        {'muted': false, 'muted_until': null},
      ]);
      expect(
        ConversationMute.fromJson({
          'muted': true,
          'muted_until': '2026-11-07T10:00:00Z',
        }).isMutedAt(DateTime.utc(2026, 11, 7, 11)),
        false,
      );
    },
  );

  for (final language in ['fr', 'en', 'es', 'it']) {
    testWidgets(
      '$language settings remain usable at 200% text and save explicit choices',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final stored = preferencesJson();
        final changes = <Object?>[];
        final session = testSession((r) async {
          if (r.url.path != accountPath) return defaultMatchesResponse(r);
          if (r.method == 'PATCH') {
            final change = jsonDecode(r.body) as Map<String, dynamic>;
            changes.add(change);
            stored.addAll(change.cast<String, Object>());
          }
          return jsonResponse(stored);
        });
        addTearDown(session.dispose);
        await session.establish(testTokens);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            theme: histaeTheme(Brightness.dark),
            localizationsDelegates: AppMessages.localizationsDelegates,
            supportedLocales: AppMessages.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: NotificationPreferencesPanel(
                  repository: NotificationPreferencesRepository(session),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('notification-messages')),
        );
        await tester.tap(find.byKey(const ValueKey('notification-messages')));
        await tester.pumpAndSettle();
        expect(changes, [
          {'messages': false},
        ]);
        await tester.ensureVisible(
          find.byKey(const Key('notification-discreet')),
        );
        await tester.tap(find.byKey(const Key('notification-discreet')));
        await tester.pumpAndSettle();
        expect(changes.last, {'discreet': true});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'conversation mute choices persist across reopening and can be removed',
    (tester) async {
      Map<String, Object?> stored = {'muted': false, 'muted_until': null};
      var writes = 0;
      final session = testSession((r) async {
        if (r.url.path != mutePath) return defaultMatchesResponse(r);
        if (r.method == 'PUT') {
          writes++;
          stored = jsonDecode(r.body) as Map<String, dynamic>;
        }
        return jsonResponse(stored);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final repository = NotificationPreferencesRepository(session);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showConversationNotifications(
                  context,
                  repository: repository,
                  matchId: testMatch,
                  now: () => DateTime.utc(2026, 11, 7, 12),
                ),
                child: const Text('Open test settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open test settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-mute-hour')));
      await tester.pumpAndSettle();
      expect(stored['muted_until'], '2026-11-07T13:00:00.000Z');
      final unmute = find.byKey(const Key('conversation-unmute'));
      await tester.tap(unmute);
      await tester.pumpAndSettle();
      expect(stored, {'muted': false, 'muted_until': null});
      await tester.tap(find.byKey(const Key('conversation-mute-indefinite')));
      await tester.pumpAndSettle();
      expect(stored, {'muted': true, 'muted_until': null});
      Navigator.of(tester.element(unmute)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open test settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('conversation-mute-indefinite')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(writes, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
