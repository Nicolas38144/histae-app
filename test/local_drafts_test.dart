import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/drafts/application/draft_controller.dart';
import 'package:histae_app/features/drafts/data/draft_vault.dart';
import 'package:histae_app/features/drafts/data/saved_answer_draft.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/answers_editor.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/profile_fixture.dart';

class _FailingVault extends MemoryDraftVault {
  bool fails = false;
  @override
  Future<void> write(String? value) async {
    if (fails) throw StateError('Synthetic local storage failure');
    await super.write(value);
  }
}

class _DelayedVault extends MemoryDraftVault {
  Completer<void>? gate;
  @override
  Future<void> write(String? value) async {
    final pending = gate;
    gate = null;
    await pending?.future;
    await super.write(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'answers and unsent messages survive relaunch; logout erases them',
    () async {
      final vault = MemoryDraftVault();
      final first = testSession((r) async => defaultMatchesResponse(r));
      await first.establish(testTokens);
      final drafts = DraftController(first, vault);
      await drafts.ready;
      drafts.setAnswers([
        const SavedAnswerDraft(
          questionOne,
          'Question',
          'Une réponse à retrouver',
        ),
      ]);
      drafts.setMessage(testMatch, 'Mon message non envoyé');
      expect(await drafts.flush(), isTrue);
      drafts.dispose();
      first.dispose();
      final second = testSession((r) async => defaultMatchesResponse(r));
      addTearDown(second.dispose);
      await second.establish(rotatedTokens);
      final restored = DraftController(second, vault);
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.answers!.single.answer, 'Une réponse à retrouver');
      expect(restored.messages[testMatch], 'Mon message non envoyé');
      await second.logout();
      await restored.ready;
      expect(vault.value, isNull);
      expect(restored.messages, isEmpty);
      expect(restored.answers, isNull);
    },
  );

  test(
    'a different account cannot recover the previous account drafts',
    () async {
      final vault = MemoryDraftVault();
      final first = testSession((r) async => defaultMatchesResponse(r));
      await first.establish(testTokens);
      final drafts = DraftController(first, vault);
      await drafts.ready;
      drafts.setMessage(testMatch, 'Texte privé du premier compte');
      await drafts.flush();
      drafts.dispose();
      first.dispose();
      final second = testSession((r) async {
        if (r.url.path == '/api/auth/me') {
          return jsonResponse(
            identityJson(
              complete: true,
              user: '55555555-5555-4555-8555-555555555555',
            ),
          );
        }
        return defaultMatchesResponse(r);
      });
      addTearDown(second.dispose);
      await second.establish(testTokens);
      final isolated = DraftController(second, vault);
      addTearDown(isolated.dispose);
      await isolated.ready;
      expect(isolated.messages, isEmpty);
      expect(vault.value, isNull);
    },
  );

  test('a delayed write cannot restore private drafts after logout', () async {
    final session = testSession((r) async => defaultMatchesResponse(r));
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final vault = _DelayedVault();
    final local = DraftController(session, vault);
    addTearDown(local.dispose);
    await local.ready;
    local.setMessage(testMatch, 'À effacer lors de la déconnexion');
    final gate = Completer<void>();
    vault.gate = gate;
    final writing = local.flush();
    await Future<void>.delayed(Duration.zero);
    await session.logout();
    gate.complete();
    await writing;
    await local.ready;
    expect(vault.value, isNull);
    expect(local.messages, isEmpty);
  });

  test('storage must remove a draft before submitting a message, preserving uncertain send keys', () async {
    var sends = 0;
    final keys = <String?>[];
    final vault = _FailingVault();
    final session = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        sends++;
        keys.add(r.headers['Idempotency-Key']);
        expect(vault.value?.contains('Texte à envoyer') ?? false, isFalse);
        throw TimeoutException('Synthetic lost response');
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final local = DraftController(session, vault);
    addTearDown(local.dispose);
    final matches = MatchesController(
      MatchesRepository(session),
      drafts: local,
      realtime: QuietRealtime(session),
    );
    addTearDown(matches.dispose);
    await matches.activate();
    await matches.openChat(testMatch);
    matches.setDraft(testMatch, 'Texte à envoyer');
    await local.flush();
    vault.fails = true;
    await matches.send('Texte à envoyer');
    expect(sends, 0);
    vault.fails = false;
    await matches.resumeSend();
    await matches.resumeSend();
    expect(sends, 2);
    expect(keys[0], isNotNull);
    expect(keys[0], keys[1]);
    expect(local.messages, isEmpty);
  });

  testWidgets(
    'the answer editor restores a local answer without publishing it',
    (tester) async {
      var writes = 0;
      final session = testSession((r) async {
        if (r.method != 'GET' &&
            r.url.path == '/api/users/me/profile-answers') {
          writes++;
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final vault = MemoryDraftVault();
      final local = DraftController(session, vault);
      addTearDown(local.dispose);
      await local.ready;
      local.setAnswers([
        const SavedAnswerDraft(
          questionOne,
          'Votre dimanche idéal ?',
          'Ma réponse encore en préparation',
        ),
      ]);
      await local.flush();
      final profile = ProfileController(
        ProfileRepository(session),
        drafts: local,
      );
      addTearDown(profile.dispose);
      await profile.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: AnswersEditor(controller: profile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(TextField), 200);
      await tester.pumpAndSettle();
      expect(find.text('Ma réponse encore en préparation'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'Une réponse modifiée dans le brouillon',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await local.flush();
      expect(
        local.answers!.single.answer,
        'Une réponse modifiée dans le brouillon',
      );
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
