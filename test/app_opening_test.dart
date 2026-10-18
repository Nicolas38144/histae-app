import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app_opening.dart';

const opening = Key('app-opening');

void main() {
  testWidgets('opening keeps content alive, blocks input and ends only once', (
    tester,
  ) async {
    var mounts = 0;
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: AppOpening(
          child: _LiveContent(onMount: () => mounts++, onTap: () => taps++),
        ),
      ),
    );
    expect(mounts, 1);
    expect(find.byKey(opening), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer'), findsNothing);
    await tester.tap(find.text('Continuer'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(opening), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(opening), findsNothing);
    expect(find.bySemanticsLabel('Continuer'), findsOneWidget);
    expect(mounts, 1);
    await tester.tap(find.text('Continuer'));
    expect(taps, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(opening), findsNothing);
    expect(mounts, 1);
    semantics.dispose();
  });

  testWidgets('reduced motion exposes the app immediately without a ticker', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppOpening(
          child: TextButton(
            onPressed: () => taps++,
            child: const Text('Continuer'),
          ),
        ),
      ),
    );
    expect(find.byKey(opening), findsNothing);
    await tester.tap(find.text('Continuer'));
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding during opening releases it and disposal is safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppOpening(child: Text('Accueil'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(opening), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(opening), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

class _LiveContent extends StatefulWidget {
  const _LiveContent({required this.onMount, required this.onTap});

  final VoidCallback onMount;
  final VoidCallback onTap;

  @override
  State<_LiveContent> createState() => _LiveContentState();
}

class _LiveContentState extends State<_LiveContent> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(onPressed: widget.onTap, child: const Text('Continuer')),
  );
}
