import 'dart:ui';

/// One portrait crop, shared by the editor, avatar preview and exported pixels.
final class PhotoCrop {
  factory PhotoCrop({
    required Size imageSize,
    int quarterTurns = 0,
    double zoom = 1,
    Offset center = const Offset(0.5, 0.5),
  }) {
    assert(imageSize.width > 0 && imageSize.height > 0);
    final turns = quarterTurns % 4;
    final size = turns.isEven
        ? imageSize
        : Size(imageSize.height, imageSize.width);
    final scale = zoom.clamp(minZoom, maxZoom);
    final base = _cover(size);
    final halfWidth = base.width / scale / size.width / 2;
    final halfHeight = base.height / scale / size.height / 2;
    return PhotoCrop._(
      imageSize,
      turns,
      scale,
      Offset(
        center.dx.clamp(halfWidth, 1 - halfWidth),
        center.dy.clamp(halfHeight, 1 - halfHeight),
      ),
    );
  }
  const PhotoCrop._(this.imageSize, this.quarterTurns, this.zoom, this.center);
  static const aspectRatio = 4 / 5;
  static const minZoom = 1.0, maxZoom = 4.0;
  final Size imageSize;
  final int quarterTurns;
  final double zoom;

  /// Normalized center in the rotated image, always clamped to real pixels.
  final Offset center;

  Size get orientedSize =>
      quarterTurns.isEven ? imageSize : Size(imageSize.height, imageSize.width);

  static Size _cover(Size size) => size.aspectRatio > aspectRatio
      ? Size(size.height * aspectRatio, size.height)
      : Size(size.width, size.width / aspectRatio);

  Rect get sourceRect {
    final size = orientedSize;
    final base = _cover(size);
    return Rect.fromCenter(
      center: Offset(center.dx * size.width, center.dy * size.height),
      width: base.width / zoom,
      height: base.height / zoom,
    );
  }

  /// BoxFit.cover on the final portrait uses exactly this centered square.
  Rect get avatarRect {
    final rect = sourceRect;
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width,
      height: rect.width,
    );
  }

  PhotoCrop withZoom(double next) => PhotoCrop(
    imageSize: imageSize,
    quarterTurns: quarterTurns,
    zoom: next,
    center: center,
  );

  PhotoCrop rotateClockwise() => PhotoCrop(
    imageSize: imageSize,
    quarterTurns: quarterTurns + 1,
    zoom: zoom,
    center: Offset(1 - center.dy, center.dx),
  );

  PhotoCrop reset() => PhotoCrop(imageSize: imageSize);

  Offset sourcePoint(Offset local, Size viewport) {
    final rect = sourceRect;
    return rect.topLeft +
        Offset(
          local.dx * rect.width / viewport.width,
          local.dy * rect.height / viewport.height,
        );
  }

  /// Keep the grabbed pixel under the fingers while panning/pinching together.
  PhotoCrop gesture({
    required double nextZoom,
    required Offset anchor,
    required Offset focalPoint,
    required Size viewport,
  }) {
    final next = withZoom(nextZoom);
    final rect = next.sourceRect;
    final pixelCenter =
        anchor +
        Offset(
          (viewport.width / 2 - focalPoint.dx) * rect.width / viewport.width,
          (viewport.height / 2 - focalPoint.dy) * rect.height / viewport.height,
        );
    return PhotoCrop(
      imageSize: imageSize,
      quarterTurns: quarterTurns,
      zoom: next.zoom,
      center: Offset(
        pixelCenter.dx / orientedSize.width,
        pixelCenter.dy / orientedSize.height,
      ),
    );
  }

  bool get isInitial =>
      quarterTurns == 0 &&
      zoom == minZoom &&
      (center - const Offset(0.5, 0.5)).distance < 0.00001;
}
