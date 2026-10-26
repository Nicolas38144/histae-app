import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/network/signed_photo_loader.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/photo_preparer.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/photo_page.dart';
import 'package:histae_app/features/profile/presentation/profile_editors.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'support/auth_fixture.dart';
import 'support/profile_fixture.dart';

class TestPhotoPreparer extends PhotoPreparer {
  Uint8List? selection;
  @override
  Future<bool> discardInterruptedSelection() async => false;
  @override
  Future<Uint8List?> choose({PhotoSource source = PhotoSource.gallery}) async =>
      selection;
}

class _CancelledPicker extends ImagePicker {
  final sources = <ImageSource>[];
  CameraDevice? preferred;
  bool? metadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    preferred = preferredCameraDevice;
    metadata = requestFullMetadata;
    return null;
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    finder,
    180,
    maxScrolls: 80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'camera and gallery use their native sources and cancellation does not upload',
    (tester) async {
      var writes = 0;
      final picker = _CancelledPicker();
      final session = testSession((r) async {
        if (r.url.path.endsWith('/photo') && r.method == 'PUT') writes++;
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
            preparer: PhotoPreparer(picker: picker),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Prendre une photo')).dy,
        lessThan(tester.getTopLeft(find.text('Choisir une photo')).dy),
      );
      await tapVisible(tester, find.text('Prendre une photo'));
      expect(picker.sources, [ImageSource.camera]);
      expect(picker.preferred, CameraDevice.front);
      expect(picker.metadata, isFalse);
      expect(c.photoIntent, isNull);
      await tapVisible(tester, find.text('Choisir une photo'));
      expect(picker.sources, [ImageSource.camera, ImageSource.gallery]);
      expect(c.photoIntent, isNull);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a captured photo stays staged until sent and an available upload has no review step',
    (tester) async {
      var writes = 0;
      final pixels = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLZkAAAAASUVORK5CYII=',
      );
      final session = testSession((r) async {
        if (r.url.path.endsWith('/photo') && r.method == 'PUT') writes++;
        if (r.url.path == '/api/users/me') {
          return jsonResponse({
            ...ownerJson(
              photo: writes == 0 ? null : 'https://storage.example/synthetic',
            ),
            'moderation': {
              'bio': null,
              'photo': writes == 0
                  ? null
                  : {'status': 'approved', 'reasons': <Object?>[]},
            },
          });
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
            preparer: TestPhotoPreparer()..selection = pixels,
            photoClient: () =>
                MockClient((_) async => http.Response.bytes(pixels, 200)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Prendre une photo'));
      expect(c.photoIntent, isNotNull);
      expect(writes, 0);
      await tapVisible(tester, find.text('Envoyer ou reprendre cette photo'));
      expect(writes, 1);
      expect(c.photoIntent, isNull);
      expect(c.profile?.photo, isNotNull);
      expect(find.text('Photo enregistrée.'), findsOneWidget);
      expect(find.textContaining('vérification'), findsNothing);
      expect(find.textContaining('après validation'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'question picker excludes selected questions and saves the explicit order of three answers',
    (tester) async {
      const third = '66666666-6666-4666-8666-666666666666';
      List<dynamic>? saved;
      final session = testSession((r) async {
        if (r.url.path == '/api/profile-questions') {
          return jsonResponse({
            'questions': [
              questionJson(questionOne, 'Votre dimanche idéal ?', 1),
              questionJson(questionTwo, 'Ce qui vous fait sourire ?', 2),
              questionJson(third, 'Une petite aventure ?', 3),
            ],
          });
        }
        if (r.url.path == '/api/users/me/profile-answers') {
          if (r.method == 'PUT') {
            saved = jsonDecode(r.body)['answers'] as List<dynamic>;
          }
          return jsonResponse({
            'answers': [
              answerJson(questionOne, 'Une promenade au grand air.', 0),
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
      await tapVisible(tester, find.text('Ajouter une question'));
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Votre dimanche idéal ?'),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Recherche'),
        'sourire',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Une petite aventure ?'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Ce qui vous fait sourire ?'));
      await tester.pumpAndSettle();
      final secondField = find.widgetWithText(TextField, 'Réponse 2');
      await tester.ensureVisible(secondField);
      await tester.pumpAndSettle();
      await tester.enterText(secondField, 'La cuisine et les amis.');
      await tapVisible(tester, find.text('Ajouter une question'));
      await tester.tap(find.text('Une petite aventure ?'));
      await tester.pumpAndSettle();
      final thirdField = find.widgetWithText(TextField, 'Réponse 3');
      await tester.ensureVisible(thirdField);
      await tester.pumpAndSettle();
      await tester.enterText(thirdField, 'Un week-end en train.');
      expect(find.text('Ajouter une question'), findsNothing);
      await tapVisible(tester, find.byTooltip('Monter la réponse 3'));
      await tapVisible(tester, find.byTooltip('Monter la réponse 2'));
      await tapVisible(tester, find.text('Enregistrer mes réponses'));
      expect(saved, isNull);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(saved, [
        {'question_id': third, 'answer': 'Un week-end en train.'},
        {'question_id': questionOne, 'answer': 'Une promenade au grand air.'},
        {'question_id': questionTwo, 'answer': 'La cuisine et les amis.'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
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
      expect(find.byType(IdentityEditor), findsNothing);
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
    expect(find.byType(IdentityEditor), findsNothing);
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
      await tester.drag(find.byType(ListView).first, const Offset(0, 1400));
      await tester.pumpAndSettle();
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
      expect(find.byType(IdentityEditor), findsNothing);
      expect(find.text('Brouillon privé'), findsNothing);
    },
  );
  testWidgets(
    'owner signed URL is fetched without Bearer, purged on deadline and refreshed explicitly',
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
      await tester.pump(privatePhotoLifetime);
      await tester.pumpAndSettle();
      expect(reads, before);
      expect(downloads, downloadsBefore);
      expect(find.byType(Image), findsNothing);
      await c.load();
      await tester.pumpAndSettle();
      expect(reads, greaterThan(before));
      expect(downloads, greaterThan(downloadsBefore));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
