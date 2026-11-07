import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/photo_crop_renderer.dart';
import '../domain/photo_crop.dart';

class PhotoCropImage extends StatelessWidget {
  const PhotoCropImage({
    super.key,
    required this.image,
    required this.crop,
    required this.label,
    this.avatar = false,
    this.grid = false,
  });
  final ui.Image image;
  final PhotoCrop crop;
  final String label;
  final bool avatar, grid;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: CustomPaint(painter: _CropPainter(image, crop, avatar, grid)),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop, this.avatar, this.grid);
  final ui.Image image;
  final PhotoCrop crop;
  final bool avatar, grid;
  @override
  void paint(Canvas canvas, Size size) {
    paintPhotoCrop(canvas, image, crop, size, avatar: avatar);
    if (!grid) return;
    final paint = Paint()
      ..color = const Color(0x66ffffff)
      ..strokeWidth = 1;
    for (final part in [1, 2]) {
      final x = size.width * part / 3, y = size.height * part / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      !identical(old.image, image) ||
      old.crop != crop ||
      old.avatar != avatar ||
      old.grid != grid;
}
