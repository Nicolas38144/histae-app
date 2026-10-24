import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consent_control.dart';
import 'package:histae_app/features/consents/presentation/consent_strings.dart';

void main() {
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
                                updatedAt: null,
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
