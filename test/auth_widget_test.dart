import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/consents/data/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consents_page.dart';

import 'support/auth_fixture.dart';

void main() {
  testWidgets(
    'an older sensitive grant can still be withdrawn without accepting the new version',
    (tester) async {
      final session = testSession((request) async {
        if (request.url.path.endsWith('consents')) {
          final json = consentJson(
            complete: true,
            grants: {ConsentType.sensitive: true},
          );
          final sensitive =
              (json['consents'] as List)[2] as Map<String, dynamic>;
          sensitive['document_version'] = 'older-version';
          return jsonResponse(json);
        }
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(home: ConsentsPage(session: session)),
      );
      expect(
        find.byKey(const Key('withdraw-terms_of_service_acceptance')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('withdraw-privacy_notice_acknowledgement')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Retirer mon consentement précédent'),
        200,
      );
      await tester.ensureVisible(
        find.text('Retirer mon consentement précédent'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer mon consentement précédent'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmer le retrait'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(session.consents!.consents[2].documentVersion, 'older-version');
    },
  );
  testWidgets(
    'returning from a document keeps unsaved choices only for unchanged versions',
    (tester) async {
      var version = 'v1';
      final session = testSession(
        (request) async => request.url.path.endsWith('consents')
            ? jsonResponse(consentJson(version: version))
            : defaultAuthResponse(request),
      );
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      await session.establish(testTokens);
      await tester.pumpAndSettle();
      final checkbox = find.byKey(Key(ConsentType.terms.wireName));
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      version = 'v2';
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    },
  );
  Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'registration is explicit and private space requires OTP then server consent completion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var complete = false;
      final puts = <Object?>[];
      final session = testSession((request) async {
        if (request.method == 'PUT') {
          puts.add(jsonDecode(request.body));
          complete = true;
        }
        return defaultAuthResponse(request, complete: complete);
      });
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsNothing);
      expect(find.text('J’ai déjà un compte'), findsOneWidget);
      await revealAndTap(tester, find.text('Créer mon compte'));
      await tester.enterText(
        find.byKey(const Key('phone')),
        '+33 6 12 34 56 78',
      );
      await revealAndTap(tester, find.text('Demander un code'));
      expect(
        find.textContaining('Saisissez le code dès que vous le recevez.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('otp')), '123456');
      await revealAndTap(tester, find.text('Vérifier le code'));
      expect(session.phase, SessionPhase.needsConsents);
      expect(find.text('Mon profil'), findsNothing);
      final boxes = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(boxes, hasLength(2));
      final documents = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(documents, hasLength(2));
      expect(documents.every((box) => box.value == false), isTrue);
      expect(boxes.every((box) => box.value == false), isTrue);
      expect(find.text('Se déconnecter'), findsOneWidget);
      await revealAndTap(tester, find.byKey(Key(ConsentType.terms.wireName)));
      await revealAndTap(tester, find.byKey(Key(ConsentType.privacy.wireName)));
      await revealAndTap(tester, find.text('Enregistrer mes choix'));
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsOneWidget);
      expect(puts, [
        {
          'consents': [
            {'consent_type': 'terms_of_service_acceptance', 'granted': true},
            {'consent_type': 'privacy_notice_acknowledgement', 'granted': true},
          ],
        },
      ]);
      await revealAndTap(tester, find.text('Vos choix et votre vie privée'));
      expect(find.text('Vie privée et sécurité'), findsOneWidget);
      await revealAndTap(tester, find.text('Mes consentements'));
      expect(find.text('Vos consentements'), findsOneWidget);
      expect(find.textContaining('Accord enregistré'), findsNothing);
      await revealAndTap(tester, find.text('Se déconnecter'));
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.text('Vos consentements'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'documents hide version labels while keeping server URLs and explicit acceptance',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = testSession(
        (request) async => defaultAuthResponse(request),
      );
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ConsentsPage(
            session: session,
            openDocument: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      );
      expect(find.text('Lire le document'), findsNWidgets(4));
      await tester.tap(find.text('Lire le document').first);
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://legal.example/terms/v1');
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((box) => box.value == false),
        isTrue,
      );
    },
  );

  testWidgets(
    'sensitive consent withdrawal describes erasure and requires explicit confirmation',
    (tester) async {
      var granted = true;
      var puts = 0;
      final session = testSession((request) async {
        if (request.method == 'PUT') {
          puts++;
          expect(jsonDecode(request.body), {
            'consents': [
              {'consent_type': 'sensitive_data_consent', 'granted': false},
            ],
          });
          granted = false;
        }
        if (request.url.path.endsWith('consents')) {
          return jsonResponse(
            consentJson(
              complete: true,
              grants: {ConsentType.sensitive: granted},
            ),
          );
        }
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(home: ConsentsPage(session: session)),
      );
      await revealAndTap(
        tester,
        find.byKey(Key(ConsentType.sensitive.wireName)),
      );
      expect(
        find.textContaining('efface votre sexe et vos préférences'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(puts, 0);
      await revealAndTap(
        tester,
        find.byKey(Key(ConsentType.sensitive.wireName)),
      );
      await tester.tap(find.text('Confirmer le retrait'));
      await tester.pumpAndSettle();
      expect(puts, 1);
      expect(
        session.consents!.consents
            .firstWhere((c) => c.type == ConsentType.sensitive)
            .granted,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(Key(ConsentType.sensitive.wireName)),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'accepted documents have status labels and optional switches reflect only saved server choices',
    (tester) async {
      final grants = {ConsentType.sensitive: true, ConsentType.location: true};
      final writes = <Object?>[];
      var reject = false;
      final session = testSession((request) async {
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          writes.add(body);
          if (reject) return apiError(503, 'service_unavailable');
          final change = (body['consents'] as List).single as Map;
          grants[ConsentType.parse(change['consent_type'] as String)] =
              change['granted'] as bool;
        }
        if (request.url.path.endsWith('consents')) {
          return jsonResponse(consentJson(complete: true, grants: grants));
        }
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(home: ConsentsPage(session: session)),
      );
      for (final type in [ConsentType.sensitive, ConsentType.location]) {
        final control = find.byKey(Key(type.wireName));
        await tester.scrollUntilVisible(control, 200);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(control).value, isTrue);
      }
      expect(find.byType(CheckboxListTile), findsNothing);
      for (final type in [ConsentType.terms, ConsentType.privacy]) {
        final status = find.text(
          type == ConsentType.terms ? 'CGU acceptées' : 'Notice consultée',
        );
        await tester.scrollUntilVisible(status, 200);
        await tester.pumpAndSettle();
        expect(status, findsOneWidget);
        expect(find.byKey(Key(type.wireName)), findsNothing);
        final document = find.descendant(
          of: find.byKey(Key('acknowledged-${type.wireName}')),
          matching: find.text('Lire le document'),
        );
        expect(document, findsOneWidget);
      }
      expect(writes, isEmpty);
      for (final type in [ConsentType.sensitive, ConsentType.location]) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final finder = find.byKey(Key(type.wireName));
        await revealAndTap(tester, finder);
        await tester.tap(find.text('Confirmer le retrait'));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(finder).value, isFalse);
        await revealAndTap(tester, finder);
        expect(tester.widget<SwitchListTile>(finder).value, isTrue);
        expect(writes.sublist(writes.length - 2), [
          {
            'consents': [
              {'consent_type': type.wireName, 'granted': false},
            ],
          },
          {
            'consents': [
              {'consent_type': type.wireName, 'granted': true},
            ],
          },
        ]);
      }
      reject = true;
      final location = find.byKey(Key(ConsentType.location.wireName));
      await revealAndTap(tester, location);
      await tester.tap(find.text('Confirmer le retrait'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(location).value, isTrue);
      expect(grants[ConsentType.location], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'incomplete registration can logout at 200 percent text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = testSession(
        (request) async => defaultAuthResponse(request),
      );
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(home: ConsentsPage(session: session, onboarding: true)),
      );
      await revealAndTap(tester, find.text('Se déconnecter'));
      expect(session.phase, SessionPhase.signedOut);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login and registration actions meet accessibility target and label guidelines',
    (tester) async {
      final session = testSession(
        (request) async => defaultAuthResponse(request),
      );
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
}
