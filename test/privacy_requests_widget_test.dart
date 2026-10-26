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
    'only manual correction remains and its message and reply are visible in history',
    (tester) async {
      var created = false, deletes = 0, exports = 0;
      const details =
          'Corriger une information historique que je ne peux pas modifier.';
      final writes = <Object?>[];
      final session = testSession((r) async {
        if (r.method == 'DELETE') deletes++;
        if (r.url.path.endsWith('/data-export')) exports++;
        if (r.url.path.endsWith('/data-subject-requests')) {
          if (r.method == 'POST') {
            writes.add(jsonDecode(r.body));
            created = true;
            return jsonResponse({
              ...rightsJson(type: 'rectification'),
              'details': details,
              'id': otherSessionId,
            }, 201);
          }
          return jsonResponse({
            'requests': [
              rightsJson(type: 'erasure'),
              if (created)
                {
                  ...rightsJson(type: 'rectification'),
                  'details': details,
                  'id': otherSessionId,
                  'response': 'La donnée historique a été corrigée.',
                  'status': 'completed',
                },
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
      expect(find.byType(PrivacyChoice<DataRight>), findsNothing);
      expect(
        c.rights.any((request) => request.type == DataRight.erasure),
        isTrue,
      );
      final initialHelp = rightDescription(strings, DataRight.rectification);
      expect(find.text(initialHelp), findsNothing);
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(initialHelp), findsOneWidget);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(initialHelp), findsNothing);
      expect(writes, isEmpty);
      final submit = find.text(
        strings.messages.privacyDetailPageSubmitMyRequest,
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(strings.messages.privacyRequestDetailsInvalid),
        findsOneWidget,
      );
      final field = find.byType(TextFormField);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, '  $details  ');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(details),
        ),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.tap(find.text(strings.messages.privacyDetailPageSubmit));
      await tester.pumpAndSettle();
      expect(writes, [
        {'type': 'rectification', 'details': details},
      ]);
      expect(deletes, 0);
      expect(exports, 0);
      expect(session.hasSession, isTrue);
      expect(c.draftDetails, isEmpty);
      final recorded = find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text(rightLabel(strings, DataRight.rectification)),
      );
      await tester.scrollUntilVisible(
        recorded,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(recorded);
      await tester.pumpAndSettle();
      expect(find.text(details), findsOneWidget);
      expect(find.text('La donnée historique a été corrigée.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an uncertain manual request keeps its message immutable until explicitly resumed',
    (tester) async {
      const details = 'Corriger ma date de naissance : 15 avril 1998.';
      final writes = <Object?>[];
      final session = testSession((r) async {
        if (r.url.path.endsWith('/data-subject-requests')) {
          if (r.method == 'POST') {
            writes.add(jsonDecode(r.body));
            if (writes.length == 1) throw http.ClientException('offline');
            return jsonResponse({
              ...rightsJson(type: 'rectification'),
              'details': details,
            }, 201);
          }
          return jsonResponse({
            'requests': [
              if (writes.length > 1)
                {...rightsJson(type: 'rectification'), 'details': details},
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
      await c.enter(PrivacySection.rights);
      await c.request(DataRight.rectification, details: details);
      expect(c.pendingRight, DataRight.rectification);
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
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.initialValue, details);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(c.pendingRequest!.details, details);
      c.editRightDraft(details: 'A different message');
      expect(c.pendingRequest!.details, details);
      expect(writes, [
        {'type': 'rectification', 'details': details},
      ]);
      const strings = AppStrings();
      final resume = find.text(
        strings.messages.privacyDetailPageResumeThisRequest,
      );
      await tester.ensureVisible(resume);
      await tester.pumpAndSettle();
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(writes, hasLength(1));
      await tester.tap(find.text(strings.messages.privacyDetailPageSubmit));
      await tester.pumpAndSettle();
      expect(writes, [
        {'type': 'rectification', 'details': details},
        {'type': 'rectification', 'details': details},
      ]);
      expect(c.pendingRight, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(session.hasSession, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
