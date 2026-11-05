// Manual visual review of real preference widgets, using synthetic data only.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/widgets/histae_button.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/preferences_editor.dart';
import 'package:histae_app/features/registration/application/registration_draft.dart';
import 'package:histae_app/features/registration/presentation/registration_preferences_step.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/profile_fixture.dart';

const _boundary = Key('preferences-preview');
const _output = 'build/previews/preferences-2026-11-05';

Future<void> capture(WidgetTester tester, String name) async {
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_output/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('Inter', 'inter/Inter-Variable.ttf'),
      ('SourceSerif4', 'source_serif_4/SourceSerif4-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
    final bytes = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets(
    'render saved, edited, registration and large-text preference screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/preferences') {
          return jsonResponse({
            ...preferencesJson(),
            'min_age': 18,
            'max_age': 99,
            'max_distance_km': 500,
          });
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final controller = ProfileController(ProfileRepository(session));
      addTearDown(controller.dispose);
      await controller.load();

      Future<void> mount(
        String name,
        Widget page, {
        String locale = 'fr',
        double scale = 1,
      }) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(name),
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: histaeTheme(Brightness.dark),
            locale: Locale(locale),
            supportedLocales: AppMessages.supportedLocales,
            localizationsDelegates: AppMessages.localizationsDelegates,
            builder: (context, child) => RepaintBoundary(
              key: _boundary,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute<void>(builder: (_) => page),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount('saved', PreferencesEditor(controller: controller));
      expect(
        tester
            .widget<HistaeButton>(
              find.widgetWithText(HistaeButton, 'Enregistrer'),
            )
            .onPressed,
        isNull,
      );
      await capture(tester, 'saved');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('preferences-min-age')),
          matching: find.byKey(const Key('increase')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<HistaeButton>(
              find.widgetWithText(HistaeButton, 'Enregistrer'),
            )
            .onPressed,
        isNotNull,
      );
      await capture(tester, 'edited');

      await mount(
        'registration',
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(AppMessages.of(context).discoveryPageYourPreferences),
            ),
            body: RegistrationPreferencesStep(
              draft: RegistrationDraft(),
              onContinue: () {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<HistaeButton>(find.byKey(const Key('registration-next')))
            .onPressed,
        isNotNull,
      );
      await capture(tester, 'registration');

      tester.view.physicalSize = const Size(320, 844);
      for (final locale in ['fr', 'en', 'es', 'it']) {
        await mount(
          'large-$locale',
          PreferencesEditor(controller: controller),
          locale: locale,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'large-$locale');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
