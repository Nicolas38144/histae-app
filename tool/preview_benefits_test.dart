// Manual visual review with synthetic session, catalogue and payment gateway.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/billing_fixture.dart';
import '../test/support/catalog_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/matches_fixture.dart';

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
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    final iconBytes = await File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
  });

  testWidgets('preview benefits shortcuts, safe insets and enabled billing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(subscriptionJson());
      }
      return defaultContinuationResponse(r);
    });
    await session.establish(testTokens);
    final billing = BillingController(
      BillingRepository(session),
      testBillingConfig,
      MemoryCheckoutVault(),
      FakeBillingGateway(),
      realtime: QuietRealtime(session),
    );
    final catalog = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient((_) async => jsonResponse(catalogJson())),
      ),
    );
    const frame = Key('benefits-preview');
    Future<void> capture(String name) => expectLater(
      find.byKey(frame),
      matchesGoldenFile('../build/previews/benefits/$name.png'),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: HistaeApp(
          sessionController: session,
          billingController: billing,
          catalogRepository: catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/histae-signature-dark.png'),
        tester.element(find.byType(HistaeApp)),
      ),
    );
    await tester.pumpAndSettle();
    await capture('feed');
    await tester.tap(find.byKey(const Key('main-tab-profile')));
    await tester.pumpAndSettle();
    await capture('profile');
    await tester.tap(find.byKey(const Key('open-premium')));
    await tester.pumpAndSettle();
    await capture('subscription');
    await tester.scrollUntilVisible(find.text('Choisir Premium Mensuel'), 200);
    await tester.pumpAndSettle();
    await capture('subscribe-button');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-videos')));
    await tester.pumpAndSettle();
    await capture('videos');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-discovery')));
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await capture('feed-large-text');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
