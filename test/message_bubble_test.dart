import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/presentation/message_bubble.dart';

void main() {
  final message = ChatMessage(
    'outgoing',
    'match',
    'owner',
    'Un message à relire.',
    DateTime.utc(2026, 10, 26, 12),
    DateTime.utc(2026, 10, 26, 12, 1),
  );

  Widget conversation({GlobalKey<NavigatorState>? navigator}) => MaterialApp(
    navigatorKey: navigator,
    theme: histaeTheme(Brightness.dark),
    locale: const Locale('fr'),
    localizationsDelegates: AppMessages.localizationsDelegates,
    supportedLocales: AppMessages.supportedLocales,
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 300,
              child: MessageBubble(message: message, own: true),
            ),
          ),
          const SizedBox(height: 1200),
        ],
      ),
    ),
  );

  testWidgets(
    'message dates are temporary, restart on tap and never move the bubble',
    (tester) async {
      await tester.pumpWidget(conversation());
      await tester.pumpAndSettle();
      final date = const AppStrings().shortDateTime(message.createdAt);
      final bubble = find.byType(MessageBubble);
      final original = tester.getRect(bubble);
      expect(find.text(date), findsNothing);
      await tester.tap(find.text(message.content));
      await tester.pump();
      expect(find.text(date), findsOneWidget);
      expect(tester.getRect(bubble), original);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text(message.content));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(date), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text(date), findsNothing);
      await tester.tap(find.text(message.content));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(find.text(date), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'dates disappear on a covered route or background and stay hidden on return',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(conversation(navigator: navigator));
      await tester.pumpAndSettle();
      final date = const AppStrings().shortDateTime(message.createdAt);
      await tester.tap(find.text(message.content));
      await tester.pump();
      expect(find.text(date), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other screen')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(date, skipOffstage: false), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text(date), findsNothing);
      await tester.tap(find.text(message.content));
      await tester.pump();
      expect(find.text(date), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text(date), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text(date), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
