import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/widgets/account_identifier.dart';

const account = '11111111-1111-4111-8111-111111111111';
void main() {
  for (final language in ['fr', 'en', 'es', 'it']) {
    testWidgets(
      'private account ID is selectable and copied at 200% in $language',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final messages = lookupAppMessages(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppMessages.localizationsDelegates,
            supportedLocales: AppMessages.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: const SizedBox(
                  width: 320,
                  child: AccountIdentifier(userId: account),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(find.text(account), findsOneWidget);
        await tester.tap(find.byTooltip(messages.accountIdentifierCopy));
        await tester.pumpAndSettle();
        expect(copied, account);
        expect(find.text(messages.accountIdentifierCopied), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'clipboard failure is localized without exposing platform details',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'synthetic_failure');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AccountIdentifier(userId: account)),
        ),
      );
      await tester.tap(find.byTooltip('Copier mon identifiant'));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de copier l’identifiant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
