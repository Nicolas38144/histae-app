import 'dart:math' as math;
import 'dart:ui';

import '../domain/photo_crop.dart';

/// Draw the same orientation and source rectangle for preview and upload.
void paintPhotoCrop(
  Canvas canvas,
  Image image,
  PhotoCrop crop,
  Size viewport, {
  bool avatar = false,
}) {
  final rect = avatar ? crop.avatarRect : crop.sourceRect;
  canvas.save();
  canvas.clipRect(Offset.zero & viewport);
  canvas.drawRect(
    Offset.zero & viewport,
    Paint()..color = const Color(0xff000000),
  );
  canvas.scale(viewport.width / rect.width, viewport.height / rect.height);
  canvas.translate(-rect.left, -rect.top);
  switch (crop.quarterTurns) {
    case 1:
      canvas.translate(image.height.toDouble(), 0);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(image.width.toDouble(), image.height.toDouble());
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(0, image.width.toDouble());
      canvas.rotate(-math.pi / 2);
  }
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}
