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
      await tester.scrollUntilVisible(find.text('Retirer mon accord'), 200);
      await tester.ensureVisible(find.text('Retirer mon accord'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer mon accord'));
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
      expect(find.text('Votre espace Histae'), findsNothing);
      expect(find.text('J’ai déjà un compte'), findsOneWidget);
      await revealAndTap(tester, find.text('Créer mon compte'));
      await tester.enterText(
        find.byKey(const Key('phone')),
        '+33 6 12 34 56 78',
      );
      await revealAndTap(tester, find.text('Demander un code'));
      expect(
        find.textContaining('Cela ne confirme pas la réception du SMS.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('otp')), '123456');
      await revealAndTap(tester, find.text('Vérifier le code'));
      expect(session.phase, SessionPhase.needsConsents);
      expect(find.text('Votre espace Histae'), findsNothing);
      final boxes = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(boxes, hasLength(4));
      expect(boxes.every((box) => box.value == false), isTrue);
      expect(find.text('Se déconnecter'), findsOneWidget);
      await revealAndTap(tester, find.byKey(Key(ConsentType.terms.wireName)));
      await revealAndTap(tester, find.byKey(Key(ConsentType.privacy.wireName)));
      await revealAndTap(tester, find.text('Enregistrer mes choix'));
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Votre espace Histae'), findsOneWidget);
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
      expect(find.textContaining('Accord enregistré'), findsNWidgets(2));
      await revealAndTap(tester, find.text('Se déconnecter'));
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.text('Vos consentements'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Votre espace Histae'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'documents use the server URL/version and accepting is never preselected',
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
      expect(find.text('Lire le document — version v1'), findsNWidgets(4));
      await tester.tap(find.text('Lire le document — version v1').first);
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://legal.example/terms/v1');
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
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
      await revealAndTap(tester, find.text('Retirer mon accord'));
      expect(
        find.textContaining('efface votre sexe et vos préférences'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(puts, 0);
      await revealAndTap(tester, find.text('Retirer mon accord'));
      await tester.tap(find.text('Confirmer le retrait'));
      await tester.pumpAndSettle();
      expect(puts, 1);
      expect(
        session.consents!.consents
            .firstWhere((c) => c.type == ConsentType.sensitive)
            .granted,
        isFalse,
      );
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
