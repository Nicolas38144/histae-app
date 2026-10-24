import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/widgets/app_privacy_shield.dart';

void main() {
  void resume(WidgetTester tester) {
    final binding = tester.binding;
    if (binding.lifecycleState == AppLifecycleState.paused) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    if (binding.lifecycleState == AppLifecycleState.hidden) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    if (binding.lifecycleState != AppLifecycleState.resumed) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  }

  List<String> accessibleLabels(WidgetTester tester) {
    final labels = <String>[];
    void visit(SemanticsNode node) {
      labels.add(node.getSemanticsData().label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(
      tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    return labels;
  }

  testWidgets(
    'inactive content is opaque, inaccessible and restored without losing the draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        resume(tester);
        addTearDown(() => resume(tester));
        final draft = TextEditingController();
        addTearDown(draft.dispose);
        var actions = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppMessages.localizationsDelegates,
            supportedLocales: AppMessages.supportedLocales,
            home: AppPrivacyShield(
              child: Scaffold(
                body: Column(
                  children: [
                    TextField(
                      controller: draft,
                      decoration: const InputDecoration(
                        labelText: 'Private biography',
                      ),
                    ),
                    Semantics(
                      label: 'Private conversation',
                      child: const Text('Synthetic private message'),
                    ),
                    TextButton(
                      onPressed: () => actions++,
                      child: const Text('Private action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextField),
          'An unfinished biography',
        );
        expect(
          accessibleLabels(tester)
              .any((label) => label.contains('Private conversation')),
          isTrue,
        );

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
          expect(find.byKey(const Key('app-privacy-shield')), findsOneWidget);
          expect(
            accessibleLabels(tester)
                .any((label) => label.contains('Private conversation')),
            isFalse,
          );
          expect(find.bySemanticsLabel('Contenu protégé'), findsOneWidget);
          expect(find.text('Private action').hitTestable(), findsNothing);
          expect(draft.text, 'An unfinished biography');
        }
        expect(actions, 0);
        resume(tester);
        await tester.pump();
        expect(find.byKey(const Key('app-privacy-shield')), findsNothing);
        expect(
          accessibleLabels(tester)
              .any((label) => label.contains('Private conversation')),
          isTrue,
        );
        expect(draft.text, 'An unfinished biography');
        await tester.tap(find.text('Private action'));
        expect(actions, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );
}
