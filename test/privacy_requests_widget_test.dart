import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/privacy/application/privacy_controller.dart';
import 'package:histae_app/features/privacy/data/privacy_models.dart';
import 'package:histae_app/features/privacy/data/privacy_repository.dart';
import 'package:histae_app/features/privacy/presentation/privacy_choice.dart';
import 'package:histae_app/features/privacy/presentation/privacy_detail_page.dart';
import 'package:histae_app/features/privacy/presentation/privacy_strings.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/privacy_fixture.dart';

void main() {
  testWidgets(
    'manual requests exclude self-service choices and preserve existing request history',
    (tester) async {
      var created = false, deletes = 0, exports = 0;
      final writes = <Object?>[];
      final session = testSession((r) async {
        if (r.method == 'DELETE') deletes++;
        if (r.url.path.endsWith('/data-export')) exports++;
        if (r.url.path.endsWith('/data-subject-requests')) {
          if (r.method == 'POST') {
            writes.add(jsonDecode(r.body));
            created = true;
            return jsonResponse({
              ...rightsJson(type: 'restriction'),
              'id': otherSessionId,
            }, 201);
          }
          return jsonResponse({
            'requests': [
              rightsJson(type: 'erasure'),
              if (created)
                {...rightsJson(type: 'restriction'), 'id': otherSessionId},
            ],
          });
        }
        return defaultPrivacyResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = PrivacyController(
        PrivacyRepository(session),
        exportStore: PreviewExportStore(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: PrivacyDetailPage(
            controller: c,
            section: PrivacySection.rights,
          ),
        ),
      );
      await tester.pumpAndSettle();
      const strings = AppStrings();
      final help = find.text(strings.messages.privacyRightExplanationTitle);
      final options = tester.widget<PrivacyChoice<DataRight>>(
        find.byKey(const Key('privacy-right-choice')),
      );
      expect(options.choices.keys.toSet(), {
        DataRight.rectification,
        DataRight.restriction,
        DataRight.objection,
      });
      expect(find.text(rightLabel(strings, DataRight.erasure)), findsOneWidget);

      final initialHelp = rightDescription(strings, DataRight.rectification);
      expect(find.text(initialHelp), findsNothing);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(initialHelp), findsOneWidget);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(initialHelp), findsNothing);
      expect(writes, isEmpty);
      final choice = find.descendant(
        of: find.byKey(const Key('privacy-right-choice')),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      final dialog = find.byType(SimpleDialog);
      for (final removed in [
        DataRight.access,
        DataRight.erasure,
        DataRight.portability,
      ]) {
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(rightLabel(strings, removed)),
          ),
          findsNothing,
        );
      }
      final restriction = find.descendant(
        of: dialog,
        matching: find.text(rightLabel(strings, DataRight.restriction)),
      );
      await tester.ensureVisible(restriction);
      await tester.tap(restriction);
      await tester.pumpAndSettle();
      final selectedHelp = rightDescription(strings, DataRight.restriction);
      expect(find.text(selectedHelp), findsNothing);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(selectedHelp), findsOneWidget);
      expect(writes, isEmpty);
      final submit = find.text(
        strings.messages.privacyDetailPageSubmitMyRequest,
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(writes, isEmpty);
      await tester.tap(find.text(strings.messages.privacyDetailPageSubmit));
      await tester.pumpAndSettle();
      expect(writes, [
        {'type': 'restriction'},
      ]);
      expect(deletes, 0);
      expect(exports, 0);
      expect(session.hasSession, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an uncertain existing request keeps its original type until explicitly resumed',
    (tester) async {
      final writes = <Object?>[];
      final session = testSession((r) async {
        if (r.url.path.endsWith('/data-subject-requests')) {
          if (r.method == 'POST') {
            writes.add(jsonDecode(r.body));
            if (writes.length == 1) throw http.ClientException('offline');
            return jsonResponse(rightsJson(type: 'erasure'), 201);
          }
          return jsonResponse({
            'requests': [if (writes.length > 1) rightsJson(type: 'erasure')],
          });
        }
        return defaultPrivacyResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = PrivacyController(
        PrivacyRepository(session),
        exportStore: PreviewExportStore(),
      );
      addTearDown(c.dispose);
      await c.enter(PrivacySection.rights);
      await c.request(DataRight.erasure);
      expect(c.pendingRight, DataRight.erasure);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: PrivacyDetailPage(
            controller: c,
            section: PrivacySection.rights,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const Key('privacy-right-choice'));
      final pending = tester.widget<PrivacyChoice<DataRight>>(choice);
      expect(pending.value, DataRight.erasure);
      expect(pending.onChanged, isNull);
      expect(pending.choices.keys, isNot(contains(DataRight.access)));
      expect(pending.choices.keys, isNot(contains(DataRight.portability)));
      expect(writes, [
        {'type': 'erasure'},
      ]);
      const strings = AppStrings();
      final resume = find.text(
        strings.messages.privacyDetailPageResumeThisRequest,
      );
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(writes, hasLength(1));
      await tester.tap(find.text(strings.messages.privacyDetailPageSubmit));
      await tester.pumpAndSettle();
      expect(writes, [
        {'type': 'erasure'},
        {'type': 'erasure'},
      ]);
      expect(c.pendingRight, isNull);
      final ready = tester.widget<PrivacyChoice<DataRight>>(choice);
      expect(ready.value, DataRight.rectification);
      expect(ready.choices.keys, isNot(contains(DataRight.erasure)));
      expect(ready.onChanged, isNotNull);
      expect(session.hasSession, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
