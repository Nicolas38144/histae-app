import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/privacy/application/privacy_controller.dart';
import 'package:histae_app/features/privacy/data/privacy_models.dart';
import 'package:histae_app/features/privacy/data/privacy_repository.dart';
import 'package:histae_app/features/privacy/presentation/privacy_detail_page.dart';
import 'package:histae_app/features/privacy/presentation/privacy_strings.dart';

import 'support/auth_fixture.dart';
import 'support/privacy_fixture.dart';

void main() {
  testWidgets(
    'request help expands without submitting, and erasure remains an explicitly confirmed request',
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
            return jsonResponse(rightsJson(type: 'erasure'), 201);
          }
          return jsonResponse({
            'requests': [if (created) rightsJson(type: 'erasure')],
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
      final accessHelp = rightDescription(strings, DataRight.access);
      expect(find.text(accessHelp), findsNothing);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(accessHelp), findsOneWidget);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(accessHelp), findsNothing);
      expect(writes, isEmpty);
      final choice = find.descendant(
        of: find.byKey(const Key('privacy-right-choice')),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      final erasure = find.text(rightLabel(strings, DataRight.erasure));
      await tester.ensureVisible(erasure);
      await tester.tap(erasure);
      await tester.pumpAndSettle();
      final erasureHelp = rightDescription(strings, DataRight.erasure);
      expect(find.text(erasureHelp), findsNothing);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(erasureHelp), findsOneWidget);
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
        {'type': 'erasure'},
      ]);
      expect(deletes, 0);
      expect(exports, 0);
      expect(session.hasSession, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
