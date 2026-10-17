import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/consents/data/consent_state.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/photo_preparer.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/photo_page.dart';
import 'package:histae_app/features/profile/presentation/profile_editors.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/profile_fixture.dart';

class TestPhotoPreparer extends PhotoPreparer {
  @override
  Future<bool> discardInterruptedSelection() async => false;
  @override
  Future<Uint8List?> choose() async => null;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'missing owner profile can be created after majority validation',
    (tester) async {
      Map<String, dynamic>? profile;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me') {
          return profile == null
              ? apiError(404, 'profile_not_found')
              : jsonResponse({
                  ...profile!,
                  'user_id': testUser,
                  'profile_answers': <Object?>[],
                  'moderation': {'bio': null, 'photo': null},
                });
        }
        if (r.url.path == '/api/users/me/profile') {
          profile = jsonDecode(r.body) as Map<String, dynamic>;
          return jsonResponse({'message': 'profile updated'});
        }
        return defaultProfileResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Créer mon profil'));
      await tester.enterText(find.widgetWithText(TextField, 'Prénom'), 'Alex');
      await tester.enterText(
        find.widgetWithText(TextField, 'Date de naissance'),
        '1995-06-12',
      );
      await tapVisible(tester, find.text('Enregistrer'));
      expect(profile, {
        'firstname': 'Alex',
        'birthdate': '1995-06-12',
        'sex': null,
        'bio': null,
      });
      expect(find.text('Votre espace Histae'), findsOneWidget);
    },
  );
  testWidgets('profile edits never silently erase sex or bio', (tester) async {
    Map<String, dynamic>? patch;
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/consents') {
        return jsonResponse(
          consentJson(complete: true, grants: {ConsentType.sensitive: true}),
        );
      }
      if (r.method == 'PATCH') {
        patch = jsonDecode(r.body) as Map<String, dynamic>;
      }
      return defaultProfileResponse(r);
    });
    await session.establish(testTokens);
    await tester.pumpWidget(HistaeApp(sessionController: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-profile')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Modifier ma présentation'));
    await tester.enterText(find.widgetWithText(TextField, 'Prénom'), 'Alex');
    await tapVisible(tester, find.text('Enregistrer'));
    expect(patch?['firstname'], 'Alex');
    expect(patch?['sex'], 'female');
    expect(patch?['bio'], ownerJson()['bio']);
    expect(find.text('Votre espace Histae'), findsOneWidget);
  });
  testWidgets(
    'minor birthdate is rejected before network and unsaved edits ask before leaving',
    (tester) async {
      var patches = 0;
      final session = testSession((r) async {
        if (r.method == 'PATCH') patches++;
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => IdentityEditor(controller: c),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Date de naissance'),
        '2020-01-01',
      );
      await tapVisible(tester, find.text('Enregistrer'));
      expect(patches, 0);
      expect(
        find.text('Histae est réservé aux personnes de 18 ans et plus.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Votre présentation'), findsOneWidget);
    },
  );
  testWidgets(
    'answer order is retained and an empty replacement needs explicit confirmation',
    (tester) async {
      List<dynamic>? saved;
      final session = testSession((r) async {
        if (r.url.path.endsWith('profile-answers')) {
          if (r.method == 'PUT') {
            saved = jsonDecode(r.body)['answers'] as List<dynamic>;
            return jsonResponse({'answers': <Object?>[]});
          }
          return jsonResponse({
            'answers': [
              answerJson(questionOne, 'Une longue promenade', 0),
              answerJson(questionTwo, 'La lumière du matin', 1),
            ],
          });
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(MaterialApp(home: AnswersEditor(controller: c)));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Monter la réponse 2'));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'La lumière du matin',
      );
      await tapVisible(tester, find.text('Retirer').first);
      await tapVisible(tester, find.text('Retirer').first);
      await tapVisible(tester, find.text('Enregistrer mes réponses'));
      expect(find.text('Effacer toutes vos réponses ?'), findsOneWidget);
      expect(saved, isNull);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tapVisible(tester, find.text('Enregistrer mes réponses'));
      await tester.tap(find.text('Tout effacer'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    },
  );
  testWidgets(
    'privacy and logout remain reachable with unavailable profile at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = testSession(
        (r) async => r.url.path == '/api/users/me'
            ? apiError(503, 'photo_storage_unavailable')
            : defaultProfileResponse(r),
      );
      await session.establish(testTokens);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HistaeApp(sessionController: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Vos choix et votre vie privée'));
      expect(find.text('Vie privée et sécurité'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Se déconnecter'));
      await tester.scrollUntilVisible(
        find.text('Créer mon compte'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sensitive consent change closes private editor and discards its draft',
    (tester) async {
      var sensitive = true;
      final session = testSession((r) async {
        if (r.url.path.endsWith('consents')) {
          return jsonResponse(
            consentJson(
              complete: true,
              grants: {ConsentType.sensitive: sensitive},
            ),
          );
        }
        return defaultProfileResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Modifier ma présentation'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Prénom'),
        'Brouillon privé',
      );
      sensitive = false;
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(find.text('Votre espace Histae'), findsOneWidget);
      expect(find.text('Brouillon privé'), findsNothing);
    },
  );
  testWidgets(
    'owner signed URL is fetched without Bearer and refreshed before its five minute expiry',
    (tester) async {
      var reads = 0, downloads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me') {
          reads++;
          return jsonResponse(
            ownerJson(
              photo: 'https://storage.example/owner?signature=synthetic$reads',
            ),
          );
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPage(
            controller: c,
            preparer: TestPhotoPreparer(),
            photoClient: () => MockClient((r) async {
              downloads++;
              expect(r.headers['authorization'], isNull);
              expect(r.followRedirects, isFalse);
              return http.Response.bytes(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
                ),
                200,
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = reads;
      final downloadsBefore = downloads;
      expect(downloads, greaterThan(0));
      await tester.pump(const Duration(minutes: 4));
      await tester.pumpAndSettle();
      expect(reads, greaterThan(before));
      expect(downloads, greaterThan(downloadsBefore));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
