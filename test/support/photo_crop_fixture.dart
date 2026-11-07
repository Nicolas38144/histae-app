import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:histae_app/features/profile/data/photo_crop_processor.dart';
import 'package:histae_app/features/profile/data/photo_preparer.dart';
import 'package:histae_app/features/profile/domain/photo_crop.dart';

class TestPhotoPreparer extends PhotoPreparer {
  Uint8List? selection;
  final sources = <PhotoSource>[];
  @override
  Future<bool> discardInterruptedSelection() async => false;
  @override
  Future<Uint8List?> choose({PhotoSource source = PhotoSource.gallery}) async {
    sources.add(source);
    return selection;
  }
}

/// The native JPEG encoder is simulated; rasterization has separate pixel tests.
class TestPhotoCropProcessor extends PhotoCropProcessor {
  TestPhotoCropProcessor({required this.image, required this.prepared});
  final ui.Image image;
  final Uint8List prepared;
  Future<Uint8List>? pending;
  PhotoCrop? lastCrop;
  @override
  Future<ui.Image> decode(Uint8List bytes) async => image.clone();
  @override
  Future<Uint8List> prepare(ui.Image image, PhotoCrop crop) {
    lastCrop = crop;
    return pending ?? Future.value(prepared);
  }
}

Future<Uint8List> syntheticCropSource({
  int width = 80,
  int height = 100,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final part in [
    (0, 0, 0xffff0000),
    (1, 0, 0xff00ff00),
    (0, 1, 0xff0000ff),
    (1, 1, 0xffffff00),
  ]) {
    canvas.drawRect(
      ui.Rect.fromLTWH(
        part.$1 * width / 2,
        part.$2 * height / 2,
        width / 2,
        height / 2,
      ),
      ui.Paint()..color = ui.Color(part.$3),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}
