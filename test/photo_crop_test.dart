import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/photo_crop_processor.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/domain/photo_crop.dart';
import 'package:histae_app/features/profile/presentation/photo_crop_image.dart';
import 'package:histae_app/features/profile/presentation/photo_crop_page.dart';
import 'package:histae_app/features/profile/presentation/photo_page.dart';

import 'support/auth_fixture.dart';
import 'support/photo_crop_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('portrait and avatar always stay inside image bounds through pan, zoom and rotation', () {
    for (final size in [
      const Size(80, 100),
      const Size(180, 80),
      const Size(40, 300),
    ]) {
      for (var turn = 0; turn < 4; turn++) {
        for (final zoom in [0.1, 1.0, 2.0, 4.0, 12.0]) {
          for (final center in [
            const Offset(-10, 10),
            const Offset(.5, .5),
            const Offset(1, 0),
          ]) {
            final crop = PhotoCrop(
              imageSize: size,
              quarterTurns: turn,
              zoom: zoom,
              center: center,
            );
            final rect = crop.sourceRect;
            expect(rect.width / rect.height, closeTo(4 / 5, 0.000001));
            expect(rect.left, greaterThanOrEqualTo(-0.000001));
            expect(rect.top, greaterThanOrEqualTo(-0.000001));
            expect(
              rect.right,
              lessThanOrEqualTo(crop.orientedSize.width + .000001),
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(crop.orientedSize.height + .000001),
            );
            expect(crop.avatarRect.center, rect.center);
            expect(crop.avatarRect.width, crop.avatarRect.height);
            expect(rect.contains(crop.avatarRect.topLeft), true);
          }
        }
      }
    }
    final initial = PhotoCrop(imageSize: const Size(80, 100));
    final zoomed = initial.withZoom(2);
    final anchor = zoomed.sourcePoint(
      const Offset(30, 40),
      const Size(160, 200),
    );
    final moved = zoomed.gesture(
      nextZoom: 3,
      anchor: anchor,
      focalPoint: const Offset(40, 50),
      viewport: const Size(160, 200),
    );
    expect(
      (moved.sourcePoint(const Offset(40, 50), const Size(160, 200)) - anchor)
          .distance,
      lessThan(.00001),
    );
    expect(moved.rotateClockwise().reset().isInitial, true);
  });

  test('exported pixels follow rotations and the selected region, without editor guides', () async {
    final processor = PhotoCropProcessor();
    final image = await processor.decode(await syntheticCropSource());
    addTearDown(image.dispose);
    const expected = [
      [255, 0, 0],
      [0, 0, 255],
      [255, 255, 0],
      [0, 255, 0],
    ];
    for (var turn = 0; turn < 4; turn++) {
      final png = await processor.rasterize(
        image,
        PhotoCrop(imageSize: const Size(80, 100), quarterTurns: turn),
        width: 80,
        height: 100,
      );
      final output = await processor.decode(png);
      final pixels = (await output.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset = (10 * output.width + 10) * 4;
      expect([
        pixels.getUint8(offset),
        pixels.getUint8(offset + 1),
        pixels.getUint8(offset + 2),
      ], expected[turn]);
      output.dispose();
    }
    final crop = PhotoCrop(
      imageSize: const Size(80, 100),
      zoom: 4,
      center: const Offset(.2, .2),
    );
    final output = await processor.decode(
      await processor.rasterize(image, crop, width: 80, height: 100),
    );
    final pixels = (await output.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    expect(
      [pixels.getUint8(0), pixels.getUint8(1), pixels.getUint8(2)],
      [255, 0, 0],
    );
    output.dispose();
  });

  test('large sources decode to a bounded image and oversized JPEG encodes fall back safely', () async {
    final decoder = PhotoCropProcessor();
    final image = await decoder.decode(
      await syntheticCropSource(width: 4096, height: 160),
    );
    addTearDown(image.dispose);
    expect(image.width, 2048);
    expect(image.height, 80);
    final calls = <(int, int, int)>[];
    final cropper = PhotoCropProcessor(
      encoder: (png, width, height, quality) async {
        calls.add((width, height, quality));
        return calls.length < 4
            ? (Uint8List(500001)..setRange(0, 3, [255, 216, 255]))
            : Uint8List.fromList([255, 216, 255, 217]);
      },
    );
    final jpeg = await cropper.prepare(
      image,
      PhotoCrop(
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      ),
    );
    expect(calls.length, 4);
    for (final call in calls) {
      expect(call.$1, lessThanOrEqualTo(960));
      expect(call.$2, lessThanOrEqualTo(1200));
      expect(call.$1 / call.$2, 4 / 5);
    }
    expect(jpeg.length, lessThanOrEqualTo(500000));
    final failing = PhotoCropProcessor(
      encoder: (_, _, _, _) async => Uint8List(500001),
    );
    await expectLater(
      failing.prepare(
        image,
        PhotoCrop(
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        ),
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.payloadTooLarge,
        ),
      ),
    );
  });

  for (final locale in ['fr', 'en', 'es', 'it']) {
    testWidgets(
      '$locale crop controls work at 200% text with live avatar and disabled zoom bounds',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final bytes = (await tester.runAsync(() => syntheticCropSource()))!;
        final image = (await tester.runAsync(
          () => PhotoCropProcessor().decode(bytes),
        ))!;
        addTearDown(image.dispose);
        final processor = TestPhotoCropProcessor(image: image, prepared: bytes);
        final session = testSession((r) async => defaultProfileResponse(r));
        addTearDown(session.dispose);
        await session.establish(testTokens);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            theme: histaeTheme(Brightness.dark),
            localizationsDelegates: AppMessages.localizationsDelegates,
            supportedLocales: AppMessages.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: PhotoCropPage(
              bytes: bytes,
              session: session,
              processor: processor,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final out = find.byKey(const Key('photo-crop-zoom-out'));
        await tester.scrollUntilVisible(out, 150);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(out).onPressed, isNull);
        await tester.tap(find.byKey(const Key('photo-crop-rotate')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('photo-crop-avatar-preview')),
          100,
        );
        await tester.pumpAndSettle();
        final views = tester
            .widgetList<PhotoCropImage>(find.byType(PhotoCropImage))
            .toList();
        expect(views.where((v) => v.avatar), hasLength(1));
        expect(views.every((v) => v.crop.quarterTurns == 1), true);
        final slider = tester.widget<Slider>(
          find.byKey(const Key('photo-crop-zoom')),
        );
        slider.onChanged!(4);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('photo-crop-zoom-in')))
              .onPressed,
          isNull,
        );
        if (locale == 'fr') {
          final gesture = find.byKey(const Key('photo-crop-gesture'));
          await tester.ensureVisible(gesture);
          await tester.pumpAndSettle();
          await tester.drag(gesture, const Offset(-36, 24));
          await tester.pumpAndSettle();
          final adjusted = tester
              .widgetList<PhotoCropImage>(find.byType(PhotoCropImage))
              .first
              .crop;
          expect(adjusted.center.dx, greaterThan(.5));
          expect(adjusted.center.dy, lessThan(.5));
          await tester.ensureVisible(find.byKey(const Key('photo-crop-reset')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('photo-crop-reset')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Slider>(find.byKey(const Key('photo-crop-zoom'))).value,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'cancelling a new crop preserves the prior staged photo and never uploads',
    (tester) async {
      final bytes = (await tester.runAsync(() => syntheticCropSource()))!;
      final image = (await tester.runAsync(
        () => PhotoCropProcessor().decode(bytes),
      ))!;
      addTearDown(image.dispose);
      final processor = TestPhotoCropProcessor(image: image, prepared: bytes);
      var uploads = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/photo') && r.method == 'PUT') uploads++;
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      c.setPhoto(bytes);
      final prior = c.photoIntent;
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPage(
            controller: c,
            preparer: TestPhotoPreparer()..selection = bytes,
            cropProcessor: processor,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Prendre une photo'), 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir une autre photo').last);
      await tester.pumpAndSettle();
      expect(find.byType(PhotoCropPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(PhotoCropPage))).pop();
      await tester.pumpAndSettle();
      expect(c.photoIntent, same(prior));
      expect(uploads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a crop finishing after logout cannot populate another account photo',
    (tester) async {
      final bytes = (await tester.runAsync(() => syntheticCropSource()))!;
      final image = (await tester.runAsync(
        () => PhotoCropProcessor().decode(bytes),
      ))!;
      addTearDown(image.dispose);
      final pending = Completer<Uint8List>();
      final processor = TestPhotoCropProcessor(image: image, prepared: bytes)
        ..pending = pending.future;
      final session = testSession((r) async => defaultProfileResponse(r));
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPage(
            controller: c,
            preparer: TestPhotoPreparer()..selection = bytes,
            cropProcessor: processor,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-crop-confirm')));
      await tester.pump();
      await session.logout();
      await tester.pump();
      pending.complete(bytes);
      await tester.pumpAndSettle();
      expect(c.photoIntent, isNull);
      expect(find.byType(PhotoCropImage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
