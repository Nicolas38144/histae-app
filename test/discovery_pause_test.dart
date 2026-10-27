import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/discovery/application/discovery_visibility_controller.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/scrolling.dart';

void main() {
  test('pause state is confirmed by the server, resynced after uncertainty and purged on logout', () async {
    var paused = false, lostResponse = true, writes = 0;
    Completer<http.Response>? pending;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/discovery-settings')) {
        if (r.method == 'PATCH') {
          writes++;
          paused = jsonDecode(r.body)['paused'] as bool;
          if (pending != null) return pending.future;
          if (lostResponse) return apiError(503, 'service_unavailable');
        }
        return jsonResponse({'paused': paused});
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryVisibilityController(session);
    addTearDown(c.dispose);
    await c.load();
    expect(c.paused, isFalse);
    await expectLater(c.setPaused(true), throwsA(isA<ApiFailure>()));
    expect(c.paused, isFalse);
    expect(c.uncertain, isTrue);
    await expectLater(c.setPaused(true), throwsA(isA<ApiFailure>()));
    expect(writes, 1);
    await c.load();
    expect(c.paused, isTrue);
    expect(c.uncertain, isFalse);
    lostResponse = false;
    final otherDevice = DiscoveryVisibilityController(session);
    addTearDown(otherDevice.dispose);
    await otherDevice.load();
    expect(otherDevice.paused, isTrue);
    pending = Completer<http.Response>();
    final writing = expectLater(c.setPaused(false), throwsA(isA<ApiFailure>()));
    await Future<void>.delayed(Duration.zero);
    await session.logout();
    pending.complete(jsonResponse({'paused': false}));
    await writing;
    expect(c.paused, isNull);
    expect(otherDevice.paused, isNull);
  });

  testWidgets(
    'pause hides new discoveries, preserves matches and resumes only on an explicit action',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var paused = false;
      final writes = <bool>[];
      final session = testSession((r) async {
        if (r.url.path.endsWith('/discovery-settings')) {
          if (r.method == 'PATCH') {
            paused = jsonDecode(r.body)['paused'] as bool;
            writes.add(paused);
          }
          return jsonResponse({'paused': paused});
        }
        if (r.url.path.endsWith('/discovery-status')) {
          return jsonResponse({
            ...discoveryStatusJson(ready: !paused),
            if (paused) 'required_actions': ['resume_discovery'],
          });
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      expect(find.byType(FeedProfileCard), findsOneWidget);
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('discovery-paused'));
      await tester.scrollUntilVisible(
        toggle,
        180,
        scrollable: verticalScrollables.first,
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(writes, [true]);
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Léa'), findsWidgets);
      await tester.tap(find.byKey(const Key('main-tab-discovery')));
      await tester.pumpAndSettle();
      expect(find.byType(FeedProfileCard), findsNothing);
      expect(find.text('Votre profil est en pause'), findsOneWidget);
      final resume = find.text('Reprendre la découverte');
      await tester.scrollUntilVisible(
        resume,
        160,
        scrollable: verticalScrollables.first,
      );
      await tester.ensureVisible(resume);
      await tester.pumpAndSettle();
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(writes, [true, false]);
      expect(find.byType(FeedProfileCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
