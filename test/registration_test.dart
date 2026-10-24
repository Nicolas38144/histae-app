import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/api_language.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/profile/data/profile_models.dart';
import 'package:histae_app/features/registration/application/registration_controller.dart';
import 'package:histae_app/features/registration/presentation/registration_page.dart';

import 'support/auth_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/registration_fixture.dart';

Future<RegistrationController> prepared(
  RegistrationFixture fixture, {
  bool sensitive = true,
}) async {
  final session = testSession(fixture.handle);
  final controller = RegistrationController(session);
  addTearDown(() {
    controller.dispose();
    session.dispose();
  });
  controller.draft.profile = const ProfileDraft(
    'Camille',
    '1995-06-12',
    'female',
    'Un long dimanche à raconter.',
  );
  controller.draft.preferences = const Preferences(25, 38, 40, 'both');
  await controller.loadDocuments();
  controller.next();
  controller.next();
  controller.setChoice(ConsentType.terms, true);
  controller.setChoice(ConsentType.privacy, true);
  controller.setChoice(ConsentType.sensitive, sensitive);
  controller.next();
  return controller;
}

void main() {
  test('drafts stay local, then consents precede profile and preferences after verification', () async {
    final fixture = RegistrationFixture();
    final controller = await prepared(fixture);
    expect(controller.step, RegistrationStep.phone);
    expect(fixture.requests.map((request) => request.url.path), [
      '/api/legal/documents',
    ]);
    expect(fixture.writes, isEmpty);
    expect(
      fixture.requests.single.headers.containsKey('authorization'),
      isFalse,
    );

    await controller.authenticate(testTokens);
    expect(controller.completed, isTrue);
    expect(fixture.writes.map((request) => request.url.path), [
      '/api/users/me/consents',
      '/api/users/me/profile',
      '/api/users/me/preferences',
    ]);
    expect(fixture.profile!['firstname'], 'Camille');
    expect(fixture.profile!['sex'], 'female');
    expect(fixture.preferences!['looking_for'], 'both');
  });

  test(
    'refusing sensitive consent never transmits sex or preferences',
    () async {
      final fixture = RegistrationFixture();
      final controller = await prepared(fixture, sensitive: false);
      await controller.authenticate(testTokens);
      expect(controller.completed, isTrue);
      expect(fixture.profile!['sex'], isNull);
      expect(
        fixture.requests.where(
          (request) => request.url.path.endsWith('/preferences'),
        ),
        isEmpty,
      );
      expect(fixture.grants[ConsentType.sensitive], isNull);
    },
  );

  test('changed documents return to explicit choices without losing the verified session or draft', () async {
    final fixture = RegistrationFixture();
    final controller = await prepared(fixture);
    fixture.version = 'v2';
    await controller.authenticate(testTokens);
    expect(controller.step, RegistrationStep.consents);
    expect(controller.verified, isTrue);
    expect(controller.choice(ConsentType.terms), isFalse);
    expect(controller.failure?.code, 'legal_documents_changed');
    expect(fixture.writes, isEmpty);
    expect(controller.draft.profile.firstname, 'Camille');

    controller.setChoice(ConsentType.terms, true);
    controller.setChoice(ConsentType.privacy, true);
    controller.setChoice(ConsentType.sensitive, true);
    controller.next();
    await controller.retrySave();
    expect(controller.completed, isTrue);
    expect(
      fixture.requests.where((request) => request.url.path == '/api/auth/me'),
      hasLength(1),
    );
  });

  test(
    'an existing verified account is never overwritten by a registration draft',
    () async {
      final fixture = RegistrationFixture()
        ..complete = true
        ..profile = ownerJson();
      final controller = await prepared(fixture);
      await controller.authenticate(testTokens);
      expect(controller.existingAccount, isTrue);
      expect(controller.completed, isFalse);
      expect(fixture.writes, isEmpty);
    },
  );

  test('a profile from an older onboarding is preserved after required documents are renewed', () async {
    final fixture = RegistrationFixture()..profile = ownerJson();
    final controller = await prepared(fixture);
    await controller.authenticate(testTokens);
    expect(controller.existingAccount, isTrue);
    expect(fixture.writes.map((request) => request.url.path), [
      '/api/users/me/consents',
    ]);
    expect(fixture.profile!['bio'], ownerJson()['bio']);
  });

  test('changing language while editing preferences clears consent choices without skipping the current step', () async {
    final fixture = RegistrationFixture();
    final language = ValueNotifier(ApiLanguage.fr);
    final session = testSession(
      fixture.handle,
      language: () => language.value,
      languageChanges: language,
    );
    final controller = RegistrationController(session);
    addTearDown(() {
      controller.dispose();
      session.dispose();
      language.dispose();
    });
    await controller.loadDocuments();
    controller.setChoice(ConsentType.terms, true);
    controller.next();
    language.value = ApiLanguage.en;
    await Future<void>.delayed(Duration.zero);
    expect(controller.step, RegistrationStep.preferences);
    expect(controller.choice(ConsentType.terms), isFalse);
    expect(fixture.writes, isEmpty);
  });

  test('manual recovery checks saved state instead of repeating an uncertain preferences write', () async {
    final fixture = RegistrationFixture()..losePreferencesResponse = true;
    final controller = await prepared(fixture);
    await controller.authenticate(testTokens);
    expect(controller.completed, isFalse);
    expect(controller.verified, isTrue);
    expect(controller.failure, isNotNull);
    await controller.retrySave();
    expect(controller.completed, isTrue);
    expect(
      fixture.writes.where((request) => request.url.path.endsWith('/profile')),
      hasLength(1),
    );
    expect(
      fixture.writes.where(
        (request) => request.url.path.endsWith('/preferences'),
      ),
      hasLength(1),
    );
  });

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.enterText(target, value);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sign-up opens the profile first and retains drafts when going back before the phone step',
    (tester) async {
      final fixture = RegistrationFixture();
      final session = testSession(fixture.handle);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Créer mon compte'));
      expect(find.byKey(const Key('phone')), findsNothing);
      expect(fixture.requests, isEmpty);
      await enter(tester, 'registration-firstname', 'Camille');
      await enter(tester, 'registration-birthdate', '1995-06-12');
      await enter(
        tester,
        'registration-bio',
        'Une présentation qui prend le temps de raconter mes dimanches et ce qui me fait sourire.',
      );
      await tapVisible(tester, find.byKey(const Key('registration-next')));
      expect(find.byKey(const Key('phone')), findsNothing);
      await enter(tester, 'registration-distance', '75');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('registration-firstname')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('registration-firstname')))
            .controller!
            .text,
        'Camille',
      );
      await tapVisible(tester, find.byKey(const Key('registration-next')));
      await reveal(tester, find.byKey(const Key('registration-distance')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('registration-distance')))
            .controller!
            .text,
        '75',
      );
      await tapVisible(
        tester,
        find.byKey(const Key('registration-looking-for')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Des femmes et des hommes').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('registration-next')));
      expect(fixture.requests.map((request) => request.url.path), [
        '/api/legal/documents',
      ]);
      expect(find.byKey(const Key('phone')), findsNothing);
      expect(fixture.writes, isEmpty);
      for (final type in [ConsentType.terms, ConsentType.privacy]) {
        await tapVisible(tester, find.byKey(Key(type.wireName)));
      }
      await tapVisible(tester, find.byKey(const Key('registration-next')));
      await enter(tester, 'phone', '+33 6 12 34 56 78');
      await tapVisible(tester, find.text('Demander un code'));
      await enter(tester, 'otp', '123456');
      await tapVisible(tester, find.text('Vérifier le code'));
      expect(find.byKey(const Key('main-tab-profile')), findsOneWidget);
      expect(fixture.profile!['firstname'], 'Camille');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the last page verifies the phone then completes the account without revisiting consent',
    (tester) async {
      final fixture = RegistrationFixture();
      final controller = await prepared(fixture);
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          locale: const Locale('fr'),
          home: RegistrationPage(
            controller: controller,
            onComplete: () {
              done = true;
            },
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'phone', '+33 6 12 34 56 78');
      await tapVisible(tester, find.text('Demander un code'));
      await enter(tester, 'otp', '123456');
      await tapVisible(tester, find.text('Vérifier le code'));
      expect(done, isTrue);
      expect(controller.completed, isTrue);
      expect(
        fixture.requests.where(
          (request) => request.url.path == '/api/auth/otp/verify',
        ),
        hasLength(1),
      );
      final writes = fixture.writes.toList();
      expect((jsonDecode(writes[1].body) as Map)['firstname'], 'Camille');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the registration header and long form remain usable on a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fixture = RegistrationFixture();
      final session = testSession(fixture.handle);
      final controller = RegistrationController(session);
      addTearDown(() {
        controller.dispose();
        session.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          locale: const Locale('fr'),
          home: RegistrationPage(
            controller: controller,
            onComplete: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'registration-firstname', 'Camille');
      await enter(tester, 'registration-birthdate', '1995-06-12');
      await tapVisible(tester, find.byKey(const Key('registration-next')));
      expect(controller.step, RegistrationStep.preferences);
      expect(tester.takeException(), isNull);
      expect(fixture.requests, isEmpty);
    },
  );
}
