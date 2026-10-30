import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/updates/application/store_update_controller.dart';
import 'package:histae_app/features/updates/data/store_update_gateway.dart';
import 'package:histae_app/features/updates/presentation/store_update_gate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/store_update_fixture.dart';

void main() {
  testWidgets(
    'only confirmed store updates block the navigator, preserving the current draft',
    (tester) async {
      final gateway = FakeStoreUpdateGateway();
      final c = StoreUpdateController(gateway);
      final draft = TextEditingController(text: 'Un brouillon à garder');
      final calls = ValueNotifier(0);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: histaeTheme(Brightness.dark),
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          builder: (context, child) =>
              StoreUpdateGate(controller: c, child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: draft),
                TextButton(
                  onPressed: () => calls.value++,
                  child: const Text('Underlying action'),
                ),
              ],
            ),
          ),
        ),
      );
      gateway.failCheck = true;
      await c.check();
      await tester.pumpAndSettle();
      expect(c.blocked, isFalse);
      gateway.failCheck = false;
      gateway.available = StoreUpdate(
        Uri.https('play.google.com', '/store/apps/details', {
          'id': 'com.histae.histae_app',
        }),
      );
      await c.check();
      await tester.pumpAndSettle();
      expect(c.blocked, isTrue);
      expect(find.byKey(const Key('store-update-open')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(draft.text, 'Un brouillon à garder');
      await tester.tapAt(tester.getCenter(find.text('Underlying action')));
      expect(calls.value, 0);
      gateway.opens = false;
      await tester.tap(find.byKey(const Key('store-update-open')));
      await tester.pumpAndSettle();
      expect(c.openFailed, isTrue);
      expect(c.blocked, isTrue);
      expect(calls.value, 0);
      gateway.failCheck = true;
      await c.check();
      expect(c.blocked, isTrue);
      gateway.failCheck = false;
      gateway.available = null;
      c.setActive(false);
      c.setActive(true);
      await tester.pumpAndSettle();
      expect(c.blocked, isFalse);
      expect(draft.text, 'Un brouillon à garder');
      await tester.tap(find.text('Underlying action'));
      expect(calls.value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      draft.dispose();
      calls.dispose();
      expect(gateway.disposed, isTrue);
    },
  );

  test('Apple lookup uses the actual storefront and excludes unavailable, unrelated or incompatible releases', () async {
    final context = <String, dynamic>{
      'bundle': 'com.histae.example',
      'country': 'FRA',
      'version': '1.0.3',
      'os': '17.2',
    };
    var data = <String, dynamic>{
      'bundleId': 'com.histae.example',
      'kind': 'software',
      'trackId': 123456789,
      'version': '1.0.4',
      'minimumOsVersion': '15.0',
    };
    var count = 1, requests = 0;
    final client = MockClient((r) async {
      requests++;
      expect(r.url.host, 'itunes.apple.com');
      expect(r.url.queryParameters['country'], 'FR');
      expect(
        r.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      return http.Response(
        jsonEncode({
          'resultCount': count,
          'results': count == 0 ? <Object?>[] : [data],
        }),
        200,
      );
    });
    expect(
      (await lookupAppleUpdate(context, client))!.storeUri.toString(),
      'https://apps.apple.com/fr/app/id123456789',
    );
    data['minimumOsVersion'] = '18.0';
    expect(await lookupAppleUpdate(context, client), isNull);
    data['minimumOsVersion'] = '15.0';
    data['version'] = '1.0.3';
    expect(await lookupAppleUpdate(context, client), isNull);
    data['version'] = '1.0.4';
    data['bundleId'] = 'unrelated.app';
    expect(await lookupAppleUpdate(context, client), isNull);
    data['bundleId'] = context['bundle'];
    count = 0;
    expect(await lookupAppleUpdate(context, client), isNull);
    final previous = requests;
    expect(
      await lookupAppleUpdate({...context, 'country': 'unknown'}, client),
      isNull,
    );
    expect(requests, previous);
    expect(compareStoreVersions('1.0.10', '1.0.3'), greaterThan(0));
    expect(compareStoreVersions('1.0', '1.0.0'), 0);
    expect(compareStoreVersions('1.0.4-beta', '1.0.3'), isNull);
    client.close();
  });
}
