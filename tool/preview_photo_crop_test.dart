// Real crop/editor widgets and rasterization with a generated fictional adult.
// No device picker, JPEG plugin or API/storage provider is contacted.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/photo_crop_processor.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/photo_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/photo_crop_fixture.dart';
import '../test/support/profile_fixture.dart';

const _boundary = Key('photo-crop-preview-boundary');
const _output = 'build/previews/photo-crop-2026-11-07';

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('$_output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
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
    final icons = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  testWidgets('capture local framing and both staged previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 28);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final bytes = (await tester.runAsync(
      () => File('pictures/fixtures/fictional-portrait.png').readAsBytes(),
    ))!;
    final image = (await tester.runAsync(
      () => PhotoCropProcessor().decode(bytes),
    ))!;
    addTearDown(image.dispose);
    final pending = Completer<Uint8List>();
    final processor = TestPhotoCropProcessor(image: image, prepared: bytes)
      ..pending = pending.future;
    var uploads = 0;
    final session = testSession((r) async {
      if (r.method == 'PUT' && r.url.path.endsWith('/photo')) uploads++;
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final profile = ProfileController(ProfileRepository(session));
    addTearDown(profile.dispose);
    await profile.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          theme: histaeTheme(Brightness.dark),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: PhotoPage(
            controller: profile,
            preparer: TestPhotoPreparer()..selection = bytes,
            cropProcessor: processor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(
      find.byKey(const Key('photo-crop-zoom')),
    );
    slider.onChanged!(1.2);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('photo-crop-gesture')),
      const Offset(0, 18),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'editor');
    await tester.tap(find.byKey(const Key('photo-crop-confirm')));
    await tester.pump();
    // PNG is used for the visual fixture only. Runtime exports a bounded JPEG.
    final result = (await tester.runAsync(
      () => processor.rasterize(
        image,
        processor.lastCrop!,
        width: 320,
        height: 400,
      ),
    ))!;
    expect(result.length, lessThanOrEqualTo(500000));
    pending.complete(result);
    await tester.pumpAndSettle();
    expect(profile.photoIntent, isNotNull);
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(profile.photoIntent!.bytes),
        tester.element(find.byType(PhotoPage)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Enregistrer ma photo'), 120);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer ma photo'));
    await tester.pumpAndSettle();
    await _capture(tester, 'preview');
    expect(uploads, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
