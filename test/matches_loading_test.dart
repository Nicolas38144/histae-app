import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  testWidgets(
    'matches and quota keep one fixed loading indicator through initial read and realtime revalidation',
    (tester) async {
      final matches = [Completer<http.Response>(), Completer<http.Response>()];
      final quotas = [Completer<http.Response>(), Completer<http.Response>()];
      var matchReads = 0, quotaReads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') {
          return matches[matchReads++].future;
        }
        if (r.url.path.endsWith('/continuation-quota')) {
          return quotas[quotaReads++].future;
        }
        return defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final realtime = QuietRealtime(session);
      final controller = MatchesController(
        MatchesRepository(session),
        realtime: realtime,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: MatchesPage(controller: controller),
        ),
      );
      await tester.pump();
      const key = Key('matches-loading');
      final position = tester.getTopLeft(find.byKey(key));
      void fixedIndicator() {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.getTopLeft(find.byKey(key)), position);
      }

      fixedIndicator();
      expect(
        find.text('Votre solde ne peut pas être vérifié pour le moment.'),
        findsNothing,
      );
      expect(find.text('Actualisation de vos crédits…'), findsOneWidget);
      // Pulling again during the initial load must not cancel or restart it.
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      expect(matchReads, 1);
      matches[0].complete(
        jsonResponse({
          'matches': [publicMatchJson()],
          'next_cursor': null,
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(quotaReads, 1);
      fixedIndicator();
      quotas[0].complete(jsonResponse(quotaJson()));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byKey(const Key('free-credits-remaining')), findsOneWidget);
      realtime.emit(const MobileSignal('connected'));
      await tester.pump(const Duration(milliseconds: 180));
      fixedIndicator();
      matches[1].complete(
        jsonResponse({
          'matches': [publicMatchJson()],
          'next_cursor': null,
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(quotaReads, 2);
      fixedIndicator();
      quotas[1].complete(apiError(503, 'service_unavailable'));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byKey(const Key('free-credits-remaining')), findsNothing);
      expect(
        find.text('Votre solde ne peut pas être vérifié pour le moment.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
