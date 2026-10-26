import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consent_control.dart';
import 'package:histae_app/features/consents/presentation/consent_strings.dart';

void main() {
  test('document dates are strict calendar dates independent of consent timestamps', () {
    final payload = <String, Object?>{
      'consent_type': ConsentType.terms.wireName,
      'granted': true,
      'document_version': 'v1',
      'required_document_version': 'v1',
      'document_url': 'https://legal.example/terms',
      'document_language': 'fr',
      'updated_at': '2026-10-01T12:00:00Z',
    };
    expect(PublicConsent.fromJson(payload).documentDate, isNull);
    expect(
      PublicConsent.fromJson({...payload, 'document_date': '2026-10-26'})
          .documentDate,
      DateTime(2026, 10, 26),
    );
    for (final invalid in [
      '2026-02-30',
      '2026-1-2',
      '2026-10-26T00:00:00Z',
      42,
    ]) {
      expect(
        () => PublicConsent.fromJson({...payload, 'document_date': invalid}),
        throwsA(isA<ApiFailure>()),
      );
    }
  });

  for (final locale in ['fr', 'en', 'es', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$locale at text scale $scale shows full statements and independent choices',
        (tester) async {
          final choices = {
            ConsentType.sensitive: false,
            ConsentType.location: false,
          };
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppMessages.localizationsDelegates,
              supportedLocales: AppMessages.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) => Column(
                        children: [
                          for (final type in choices.keys)
                            ConsentControl(
                              consent: PublicConsent(
                                type: type,
                                granted: false,
                                documentVersion: null,
                                requiredVersion: 'v1',
                                documentUrl: 'https://histae.com/',
                                updatedAt: '2026-10-01T12:00:00Z',
                                documentDate: DateTime(2026, 10, 26),
                              ),
                              value: choices[type]!,
                              onChanged: (value) => setState(() {
                                choices[type] = value;
                              }),
                              onOpen: () {},
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          for (final type in choices.keys) {
            expect(
              find.text(AppStrings(locale).consentLabel(type)),
              findsOneWidget,
            );
          }
          final strings = AppStrings(locale);
          expect(
            find.text(
              strings.messages.consentDocumentDate(
                strings.date(DateTime(2026, 10, 26)),
              ),
            ),
            findsNWidgets(2),
          );
          expect(
            find.textContaining(strings.date(DateTime(2026, 10, 1))),
            findsNothing,
          );
          expect(choices.values, everyElement(isFalse));
          final sensitive = find.byKey(Key(ConsentType.sensitive.wireName));
          await tester.ensureVisible(sensitive);
          await tester.tap(sensitive);
          await tester.pumpAndSettle();
          expect(choices[ConsentType.sensitive], isTrue);
          expect(choices[ConsentType.location], isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
