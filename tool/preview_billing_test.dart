// Manual visual inspection only. Synthetic account, catalogue and payments.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/config/billing_config.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/presentation/subscription_page.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/billing_fixture.dart';
import '../test/support/catalog_fixture.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/scrolling.dart';

void main() {
  setUpAll(() async {
    for (final font in [
      ('Inter', 'inter/Inter-Variable.ttf'),
      ('SourceSerif4', 'source_serif_4/SourceSerif4-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  testWidgets(
    'preview subscription states, disabled sales and store purchase confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var state = subscriptionJson();
      final session = testSession((r) async {
        if (r.url.path.endsWith('/purchase-intents')) {
          throw const SocketException('Synthetic lost response');
        }
        if (r.url.path == '/api/billing/store-products') {
          return jsonResponse(storeProductsJson());
        }
        if (r.url.path == '/api/users/me/subscription') {
          return jsonResponse(state);
        }
        return defaultAuthResponse(r, complete: true);
      });
      await session.establish(testTokens);
      final catalog = CatalogRepository(
        ApiClient(
          origin: Uri.parse('https://api.example'),
          client: MockClient((_) async => jsonResponse(catalogJson())),
        ),
      );
      const preview = Key('billing-preview');
      Future<void> screenshot(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(preview),
          matchesGoldenFile('../build/previews/$name.png'),
        );
      }

      Future<void> mount(BillingController c) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: preview,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: histaeTheme(Brightness.dark),
              locale: const Locale('fr'),
              localizationsDelegates: AppMessages.localizationsDelegates,
              supportedLocales: AppMessages.supportedLocales,
              home: SubscriptionPage(controller: c, catalog: catalog),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      var c = BillingController(
        BillingRepository(session),
        const BillingConfig(),
        FakeBillingGateway(),
        realtime: QuietRealtime(session),
      );
      await mount(c);
      await screenshot('subscription-free');
      await tester.scrollUntilVisible(
        find.textContaining('La souscription et la gestion'),
        150,
        scrollable: verticalScrollables.first,
      );
      await screenshot('subscription-disabled');
      state = subscriptionJson(
        access: true,
        status: 'past_due',
        cancel: true,
        portal: true,
      );
      await c.load();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await screenshot('subscription-past-due');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      state = subscriptionJson();
      c = BillingController(
        BillingRepository(session),
        testBillingConfig,
        FakeBillingGateway(),
        realtime: QuietRealtime(session),
      );
      await mount(c);
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-selector-premium_annual')),
        200,
        scrollable: verticalScrollables.first,
      );
      await tester.tap(find.byKey(const Key('plan-selector-premium_annual')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Choisir Premium Annuel'),
        200,
        scrollable: verticalScrollables.first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir Premium Annuel'));
      await screenshot('subscription-confirmation');
      await tester.tap(find.text('Annuler'));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      catalog.close();
      session.dispose();
    },
  );
}
