import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/l10n/language_picker.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/profile/presentation/identity_editor.dart';

import 'support/auth_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/scrolling.dart';

class MemoryLocaleStore implements LocalePreferenceStore {
  String? saved;
  bool fail = false;
  @override
  Future<String?> read() async => saved;
  @override
  Future<void> write(String language) async {
    if (fail) throw const FileSystemException();
    saved = language;
  }
}

// Catch direct literals in selected UI arguments. A syntax-only check cannot
// trace copy passed through variables, helpers, or other widget parameters.
class InterfaceLiteralAudit extends RecursiveAstVisitor<void> {
  final violations = <int>[];
  static const labels = {
    'label',
    'labelText',
    'helperText',
    'hintText',
    'tooltip',
    'semanticsLabel',
    'title',
    'body',
    'message',
  };

  void inspect(StringLiteral node) {
    // Skip nested literals inside expressions: they may be wire identifiers.
    if (node.parent is InterpolationExpression ||
        node.parent is AdjacentStrings) {
      return;
    }
    final text = switch (node) {
      SimpleStringLiteral s => s.value,
      StringInterpolation s =>
        s.elements.whereType<InterpolationString>().map((p) => p.value).join(),
      _ => '',
    };
    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(text)) return;
    final parent = node.parent;
    if (parent is SwitchExpressionCase && identical(parent.expression, node)) {
      violations.add(node.offset);
    }
    if (parent is MapLiteralEntry && identical(parent.value, node)) {
      violations.add(node.offset);
    }
    if (parent is ArgumentList && parent.parent is MethodInvocation) {
      final name = (parent.parent! as MethodInvocation).methodName.name;
      if ({'page', 'field', 'confirmAction', 'text'}.contains(name)) {
        violations.add(node.offset);
      }
    }
    if (parent is NamedExpression && labels.contains(parent.name.label.name)) {
      violations.add(node.offset);
    } else if (parent is ArgumentList &&
        parent.parent is InstanceCreationExpression) {
      final call = parent.parent! as InstanceCreationExpression;
      if ({
        'Text',
        'TextSpan',
      }.contains(call.constructorName.type.name.lexeme)) {
        violations.add(node.offset);
      }
    }
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    inspect(node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    inspect(node);
    super.visitStringInterpolation(node);
  }
}

void main() {
  test(
    'all four catalogs have complete copy, matching placeholders and UTF-8',
    () {
      Map<String, dynamic> catalog(String locale) => jsonDecode(
        File('lib/core/l10n/arb/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final french = catalog('fr');
      expect(
        AppMessages.supportedLocales.map((l) => l.languageCode).toSet(),
        LocaleController.supportedLanguages.toSet(),
      );
      final keys = french.keys.where((k) => !k.startsWith('@')).toSet();
      final placeholders = RegExp(r'\{(\w+)(?:\}|,\s*(?:plural|select))');
      Set<String> arguments(String copy) =>
          placeholders.allMatches(copy).map((m) => m[1]!).toSet();
      for (final locale in ['fr', 'en', 'es', 'it']) {
        final copy = catalog(locale);
        expect(copy.keys.where((k) => !k.startsWith('@')).toSet(), keys);
        for (final key in keys) {
          final value = copy[key] as String;
          expect(value.trim(), isNotEmpty, reason: '$locale:$key');
          expect(
            arguments(value),
            arguments(french[key] as String),
            reason: '$locale:$key',
          );
          expect(value, isNot(contains('\uFFFD')), reason: '$locale:$key');
          expect(
            value,
            isNot(matches(r'[\u00C2\u00C3][\u0080-\u00BF]')),
            reason: '$locale:$key',
          );
        }
      }
    },
  );

  test(
    'selected UI and accessibility arguments have no direct text literals',
    () {
      final violations = <String>[];
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || file.path.contains('generated')) {
          continue;
        }
        final path = file.path.replaceAll('\\', '/');
        if (!path.contains('/presentation/') &&
            !path.contains('/widgets/') &&
            !path.startsWith('lib/app/')) {
          continue;
        }
        final unit = parseString(content: file.readAsStringSync());
        final audit = InterfaceLiteralAudit();
        unit.unit.accept(audit);
        for (final offset in audit.violations) {
          violations.add(
            '${file.path}:${unit.lineInfo.getLocation(offset).lineNumber}',
          );
        }
      }
      expect(violations, isEmpty);
    },
  );

  test(
    'credit and unread message labels use the expected plural forms',
    () async {
      const expected = {
        'fr': (
          rewards: [
            '+ 1 crédit de continuation',
            '+ 2 crédits de continuation',
          ],
          unread: [
            '0 message non lu',
            '1 message non lu',
            '2 messages non lus',
          ],
          reserved: ['1 crédit réservé', '2 crédits réservés'],
        ),
        'en': (
          rewards: ['+ 1 continuation credit', '+ 2 continuation credits'],
          unread: [
            '0 unread messages',
            '1 unread message',
            '2 unread messages',
          ],
          reserved: ['1 reserved credit', '2 reserved credits'],
        ),
        'es': (
          rewards: [
            '+ 1 crédito de continuación',
            '+ 2 créditos de continuación',
          ],
          unread: [
            '0 mensajes sin leer',
            '1 mensaje sin leer',
            '2 mensajes sin leer',
          ],
          reserved: ['1 crédito reservado', '2 créditos reservados'],
        ),
        'it': (
          rewards: [
            '+ 1 credito di proseguimento',
            '+ 2 crediti di proseguimento',
          ],
          unread: [
            '0 messaggi non letti',
            '1 messaggio non letto',
            '2 messaggi non letti',
          ],
          reserved: ['1 credito riservato', '2 crediti riservati'],
        ),
      };
      for (final locale in AppMessages.supportedLocales) {
        final copy = await AppMessages.delegate.load(locale);
        final labels = expected[locale.languageCode]!;
        expect(
          [copy.videoCreditReward(1), copy.videoCreditReward(2)],
          labels.rewards,
          reason: '$locale video reward',
        );
        expect(
          [
            copy.unreadMessages(0),
            copy.unreadMessages(1),
            copy.unreadMessages(2),
          ],
          labels.unread,
          reason: '$locale unread messages',
        );
        expect(
          [copy.reservedCredits(1), copy.reservedCredits(2)],
          labels.reserved,
          reason: '$locale reserved credits',
        );
      }
    },
  );

  test('number formats and string lookups follow the requested locale', () {
    expect(const AppStrings('en').money(1234, 'EUR'), contains('12.34'));
    expect(const AppStrings('es').decimal(1.5), '1,5');
    expect(const AppStrings('en').decimal(1.5), '1.5');
    expect(const AppStrings('de').signIn, const AppStrings().signIn);
    expect(const AppStrings('en-GB').signIn, 'Sign in');
    expect(
      const AppStrings('it').clientMessage(ClientMessage.messageEmpty),
      contains('Scrivi'),
    );
  });

  test('language persists, resolves regional locales and keeps state on write failure', () async {
    final store = MemoryLocaleStore();
    final controller = LocaleController(store: store);
    addTearDown(controller.dispose);
    expect(controller.language, 'fr');
    await controller.select('es');
    final restored = LocaleController(store: store);
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.language, 'es');
    await controller.select(null);
    await restored.restore();
    expect(restored.locale, isNull);
    expect(
      LocaleController.resolve(
        const Locale('en', 'GB'),
        AppMessages.supportedLocales,
      ),
      const Locale('en'),
    );
    expect(
      LocaleController.resolve(
        const Locale('pt'),
        AppMessages.supportedLocales,
      ),
      const Locale('fr'),
    );
    store.fail = true;
    await controller.select('it');
    expect(controller.language, isNull);
    expect(controller.saveFailed, isTrue);
    store.saved = 'invalid';
    await restored.restore();
    expect(restored.language, 'fr');
  });

  testWidgets(
    'welcome language picker translates live and retains its route at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = LocaleController();
      await tester.pumpWidget(HistaeApp(localeController: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choose-language')));
      await tester.pumpAndSettle();
      for (final language in ['en', 'es', 'it', 'fr']) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('language-$language')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(find.byKey(ValueKey('language-$language')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('language-$language')));
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePage), findsOneWidget);
        expect(
          controller.language,
          language,
          reason: "radio selection must update preference",
        );
        expect(
          AppStrings.of(tester.element(find.byType(LanguagePage))).localeName,
          language,
          reason: "route must receive new locale",
        );
        expect(
          find.text(AppStrings(language).messages.languageTitle),
          findsOneWidget,
        );
        expect(find.byKey(const Key('app-opening')), findsNothing);
        expect(tester.takeException(), isNull);
      }
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'MX')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final system = find.byKey(const Key('language-system'));
      await tester.scrollUntilVisible(
        system,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(system);
      await tester.pumpAndSettle();
      await tester.tap(system);
      await tester.pumpAndSettle();
      expect(controller.language, isNull);
      expect(find.text('Idioma'), findsOneWidget);
    },
  );

  testWidgets(
    'changing language preserves authenticated route and unsaved profile text',
    (tester) async {
      final session = testSession(
        (request) async => defaultProfileResponse(request),
      );
      await session.establish(testTokens);
      final locale = LocaleController();
      await tester.pumpWidget(
        HistaeApp(sessionController: session, localeController: locale),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Modifier ma présentation'),
        160,
        scrollable: verticalScrollables.first,
      );
      await tester.ensureVisible(find.text('Modifier ma présentation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier ma présentation'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Quelques mots sur vous'),
        160,
        scrollable: verticalScrollables.first,
      );
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Quelques mots sur vous'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Draft local');
      final state = tester.state(find.byType(IdentityEditor));
      final resource = session.resourceKey;
      for (final language in ['en', 'es', 'it']) {
        await locale.select(language);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(IdentityEditor)), same(state));
        expect(find.text('Draft local'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .decoration
              ?.labelText,
          AppStrings(language).messages.identityEditorAFewWordsAboutYou,
        );
        expect(session.resourceKey, resource);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
