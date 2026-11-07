import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/network/api_failure.dart';
import '../domain/photo_crop.dart';
import 'photo_crop_renderer.dart';

typedef PhotoJpegEncoder = Future<Uint8List> Function(
  Uint8List png,
  int width,
  int height,
  int quality,
);

/// Private in-memory processing. Neither originals nor intermediate crops go to disk/API.
class PhotoCropProcessor {
  PhotoCropProcessor({PhotoJpegEncoder? encoder}) : _encoder = encoder ?? _jpeg;
  final PhotoJpegEncoder _encoder;
  static const maxDecodeDimension = 2048;
  static const maxUploadBytes = 500000;

  Future<ui.Image> decode(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 30000000) {
      throw const ApiFailure(ApiFailureKind.payloadTooLarge);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        maxDecodeDimension / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } catch (_) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        code: 'photo_crop_unavailable',
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<Uint8List> _jpeg(
    Uint8List png,
    int width,
    int height,
    int quality,
  ) => FlutterImageCompress.compressWithList(
    png,
    minWidth: width,
    minHeight: height,
    quality: quality,
    format: CompressFormat.jpeg,
    keepExif: false,
    autoCorrectionAngle: false,
  );

  Future<Uint8List> prepare(ui.Image image, PhotoCrop crop) async {
    try {
      for (final maximum in [960, 640]) {
        final width = math.max(
          4,
          (math.min(maximum, crop.sourceRect.width).floor() ~/ 4) * 4,
        );
        final height = width ~/ 4 * 5;
        final png = await rasterize(image, crop, width: width, height: height);
        for (final quality in maximum == 960 ? [88, 76, 64] : [76]) {
          final jpeg = await _encoder(png, width, height, quality);
          if (jpeg.length >= 3 &&
              jpeg[0] == 255 &&
              jpeg[1] == 216 &&
              jpeg[2] == 255 &&
              jpeg.length <= maxUploadBytes) {
            return jpeg;
          }
        }
      }
      throw const ApiFailure(ApiFailureKind.payloadTooLarge);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        code: 'photo_crop_unavailable',
      );
    }
  }

  /// Also used by pixel tests: rasterization must match the visible crop exactly.
  Future<Uint8List> rasterize(
    ui.Image image,
    PhotoCrop crop, {
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    paintPhotoCrop(
      ui.Canvas(recorder),
      image,
      crop,
      ui.Size(width.toDouble(), height.toDouble()),
    );
    final picture = recorder.endRecording();
    ui.Image? output;
    try {
      output = await picture.toImage(width, height);
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ApiFailure(ApiFailureKind.validation);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      output?.dispose();
      picture.dispose();
    }
  }
}
