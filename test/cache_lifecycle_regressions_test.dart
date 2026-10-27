// Critical cache and lifecycle regressions. Synthetic responses only.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/session_repositories.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/read_snapshots.dart';
import 'package:histae_app/core/network/signed_photo_loader.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/auth_repository.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo_page.dart';
import 'package:histae_app/features/discovery/data/discovery_models.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';
import 'support/privacy_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets(
    'read receipts require the foreground even when realtime data stays active',
    (tester) async {
      var receipts = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/messages/read')) receipts++;
        return defaultMatchesResponse(r);
      });
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      await c.activate();
      await c.openChat(testMatch);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: ChatPage(controller: c, matchId: testMatch),
        ),
      );
      await tester.pumpAndSettle();
      expect(receipts, 0);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(milliseconds: 600));
      expect(receipts, 0);
      expect(c.active, isTrue);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(milliseconds: 600));
      expect(receipts, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'main, notification and billing consumers share one event transport',
    (tester) async {
      var connections = 0, peak = 0;
      final streams = <StreamController<List<int>>>[];
      final client = MockClient.streaming((r, _) async {
        if (r.url.path.endsWith('/events')) {
          late StreamController<List<int>> stream;
          stream = StreamController<List<int>>(
            onListen: () {
              connections++;
              if (connections > peak) peak = connections;
            },
            onCancel: () {
              connections--;
              unawaited(stream.close());
            },
          );
          streams.add(stream);
          if (r is http.AbortableRequest) {
            unawaited(
              r.abortTrigger?.then((_) {
                    if (!stream.isClosed) {
                      stream.addError(http.RequestAbortedException(r.url));
                      unawaited(stream.close());
                    }
                  }) ??
                  Future<void>.value(),
            );
          }
          return http.StreamedResponse(
            stream.stream,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        if (r.url.path == '/api/users/me/subscription') {
          final response = jsonResponse(subscriptionJson());
          return http.StreamedResponse(
            Stream.value(response.bodyBytes),
            response.statusCode,
            headers: response.headers,
          );
        }
        final response = defaultNotificationsResponse(
          http.Request(r.method, r.url),
        );
        return http.StreamedResponse(
          Stream.value(response.bodyBytes),
          response.statusCode,
          headers: response.headers,
        );
      });
      final session = SessionController(
        AuthRepository(
          ApiClient(origin: Uri.parse('https://api.example'), client: client),
        ),
        MemorySessionVault(),
      );
      await session.establish(testTokens);
      final gateway = FakePushGateway();
      final vault = MemoryPushVault()
        ..record = const PushRecord(
          'https://api.example',
          testUser,
          deviceId: deviceOne,
        );
      final push = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () async => '1.0',
      );
      final repositories = SessionRepositories(
        session,
        devices: push.repository,
      );
      final billing = BillingController(
        BillingRepository(session),
        testBillingConfig,
        FakeBillingGateway(),
        realtime: repositories.realtime.channel(),
      );
      await tester.pumpWidget(
        HistaeApp(
          sessionController: session,
          pushController: push,
          repositories: repositories,
          billingController: billing,
        ),
      );
      await tester.pumpAndSettle();
      expect(connections, 1);
      await billing.activate();
      await tester.pumpAndSettle();
      expect(connections, 1);
      expect(peak, 1);
      billing.suspend();
      gateway.taps.add(
        const PushIntent(notificationOne, PushKind.newMessage, testMatch),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(connections, 1);
      expect(peak, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(connections, 1);
      expect(peak, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(connections, 0);
      for (final stream in streams) {
        unawaited(stream.close());
      }
      await gateway.close();
    },
  );

  test(
    'a message read invalidates only matching resources, retaining devices',
    () async {
      var devices = 0, histories = 0;
      final session = testSession((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/devices')) devices++;
        if (r.method == 'GET' && r.url.path.endsWith('/messages')) histories++;
        return defaultNotificationsResponse(r);
      });
      await session.establish(testTokens);
      final repositories = SessionRepositories(session);
      final scope = RequestCancellation();
      Future<Object?> read() =>
          repositories.devices.list(scope, policy: ReadPolicy.cached);
      await read();
      await read();
      expect(devices, 1);
      final matches = await repositories.matches.matches(scope);
      final match = matches.items.first;
      await repositories.matches.messages(
        match,
        scope,
        policy: ReadPolicy.cached,
      );
      await repositories.matches.readThrough(testMatch, incomingId, scope);
      await repositories.matches.messages(
        match,
        scope,
        policy: ReadPolicy.cached,
      );
      await read();
      expect(devices, 1);
      expect(histories, 2);
      repositories.dispose();
      session.dispose();
    },
  );

  test(
    'blocking from discovery updates a previously opened privacy block list',
    () async {
      var blocked = false, reads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/blocks/$candidateOne') {
          blocked = true;
          return http.Response('', 204);
        }
        if (r.url.path == '/api/users/me/blocks') {
          reads++;
          if (!blocked) return jsonResponse({'blocks': <Object?>[]});
          return defaultPrivacyResponse(r);
        }
        return defaultMatchesResponse(r);
      });
      await session.establish(testTokens);
      final repositories = SessionRepositories(session);
      final scope = RequestCancellation();
      expect(
        await repositories.privacy.blocks(scope, policy: ReadPolicy.cached),
        isEmpty,
      );
      await repositories.discovery.block(
        PendingChoice(
          FeedProfile.fromJson(candidateJson(candidateOne)),
          PendingAction.block,
        ),
        scope,
      );
      final blocks = await repositories.privacy.blocks(
        scope,
        policy: ReadPolicy.cached,
      );
      expect(blocks.single.id, candidateOne);
      expect(reads, 2);
      repositories.dispose();
      session.dispose();
    },
  );

  testWidgets('partner photo is purged at its original read deadline', (
    tester,
  ) async {
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [
            {
              ...publicMatchJson(),
              'photos_revealed': true,
              'other_user': {
                ...(publicMatchJson()['other_user'] as Map),
                'photo': 'https://photos.example/synthetic',
              },
            },
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
    await c.activate();
    await c.openChat(testMatch);
    const remaining = Duration(seconds: 2);
    c.readAt = DateTime.now().toUtc().subtract(
      privatePhotoLifetime - remaining,
    );
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: histaeTheme(Brightness.dark),
        home: PartnerPhotoPage(
          access: c,
          matchId: testMatch,
          photoClient: () =>
              MockClient((_) async => http.Response.bytes(png, 200)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(remaining + const Duration(milliseconds: 100)),
    );
    await tester.pump();
    final expired =
        DateTime.now().toUtc().difference(c.readAt!) >= privatePhotoLifetime;
    expect(expired, isTrue);
    await tester.pump(remaining + const Duration(milliseconds: 100));
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    session.dispose();
  });
}
