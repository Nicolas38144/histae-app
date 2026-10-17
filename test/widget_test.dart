import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/catalog_fixture.dart';

void main() {
  CatalogRepository repository(
    Future<http.Response> Function(http.Request) handle,
  ) => CatalogRepository(
    ApiClient(
      origin: Uri.parse('https://api.example'),
      client: MockClient(handle),
    ),
  );

  Future<void> openCatalog(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Découvrir les formules'), 200);
    await tester.ensureVisible(find.text('Découvrir les formules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Découvrir les formules'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'French public navigation remains usable without API configuration',
    (tester) async {
      await tester.pumpWidget(const HistaeApp());
      expect(find.text('Histae'), findsOneWidget);
      await openCatalog(tester);
      expect(find.text('Service non configuré'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('Découvrir les formules'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows loading then real repository data without a purchase action',
    (tester) async {
      final response = Completer<http.Response>();
      await tester.pumpWidget(
        HistaeApp(catalogRepository: repository((_) => response.future)),
      );
      await openCatalog(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(http.Response(catalogFixture(), 200));
      await tester.pumpAndSettle();
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('12,34 EUR / mois'), findsOneWidget);
      expect(find.text('98,76 EUR / an'), findsOneWidget);
      expect(find.text('Crédits inclus par semaine : 3'), findsOneWidget);
      expect(find.text('Messagerie'), findsOneWidget);
      expect(find.text('Messaging'), findsNothing);
      expect(
        find.text(
          'Retrouvez votre abonnement et les possibilités de souscription depuis votre profil.',
        ),
        findsOneWidget,
      );
      expect(find.text('Acheter'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offline message uses safe French copy and allows manual retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      HistaeApp(
        catalogRepository: repository((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('private payload');
          return http.Response('{"plans":[]}', 200);
        }),
      ),
    );
    await openCatalog(tester);
    await tester.pumpAndSettle();
    expect(find.text('Connexion indisponible'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune formule disponible'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('Retry-After disables retry without locking the back action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      HistaeApp(
        catalogRepository: repository((_) async {
          calls++;
          return http.Response(
            '{"error":{"code":"rate_limit_exceeded"}}',
            429,
            headers: {'retry-after': '30'},
          );
        }),
      ),
    );
    await openCatalog(tester);
    await tester.pumpAndSettle();
    final retry = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(retry.onPressed, isNull);
    expect(find.textContaining('Nouvel essai possible dans'), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Découvrir les formules'), findsOneWidget);
  });

  testWidgets('leaving while loading ignores a late response', (tester) async {
    final response = Completer<http.Response>();
    await tester.pumpWidget(
      HistaeApp(catalogRepository: repository((_) => response.future)),
    );
    await openCatalog(tester);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    response.complete(http.Response(catalogFixture(), 200));
    await tester.pumpAndSettle();
    expect(find.text('Découvrir les formules'), findsOneWidget);
    expect(find.text('Premium'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screens and 200 percent text keep navigation and offers readable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        HistaeApp(
          catalogRepository: repository(
            (_) async => http.Response(catalogFixture(), 200),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Découvrir les formules'), 200);
      await openCatalog(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Actualiser'), 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('suspending and resuming restarts only the interrupted read', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    var calls = 0;
    await tester.pumpWidget(
      HistaeApp(
        catalogRepository: repository((_) async {
          calls++;
          return calls == 1
              ? oldResponse.future
              : http.Response('{"plans":[]}', 200);
        }),
      ),
    );
    await openCatalog(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Aucune formule disponible'), findsOneWidget);
    oldResponse.complete(http.Response(catalogFixture(), 200));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'welcome actions meet tap target and accessible label guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const HistaeApp());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );
}
