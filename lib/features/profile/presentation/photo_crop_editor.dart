import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/photo_crop.dart';
import 'photo_crop_image.dart';

/// Only editing gestures and controls; image/session ownership stays with the page.
class PhotoCropEditor extends StatefulWidget {
  const PhotoCropEditor({
    super.key,
    required this.image,
    required this.crop,
    required this.enabled,
    required this.onChanged,
  });
  final ui.Image image;
  final PhotoCrop crop;
  final bool enabled;
  final ValueChanged<PhotoCrop> onChanged;
  @override
  State<PhotoCropEditor> createState() => _PhotoCropEditorState();
}

class _PhotoCropEditorState extends State<PhotoCropEditor> {
  double _startZoom = 1;
  Offset _anchor = Offset.zero;
  @override
  Widget build(BuildContext context) {
    final image = widget.image, crop = widget.crop;
    final enabled = widget.enabled;
    final text = AppStrings.of(context).messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text.photoCropPortrait,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: PhotoCrop.aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = constraints.biggest;
                  return GestureDetector(
                    key: const Key('photo-crop-gesture'),
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: !enabled
                        ? null
                        : (details) {
                            _startZoom = widget.crop.zoom;
                            _anchor = widget.crop.sourcePoint(
                              details.localFocalPoint,
                              viewport,
                            );
                          },
                    onScaleUpdate: !enabled
                        ? null
                        : (details) => widget.onChanged(
                            crop.gesture(
                              nextZoom: _startZoom * details.scale,
                              anchor: _anchor,
                              focalPoint: details.localFocalPoint,
                              viewport: viewport,
                            ),
                          ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: PhotoCropImage(
                            image: image,
                            crop: crop,
                            grid: true,
                            label: text.photoCropPortrait,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  key: const Key('photo-crop-avatar-preview'),
                                  child: SizedBox.square(
                                    dimension: 64,
                                    child: PhotoCropImage(
                                      image: image,
                                      crop: crop,
                                      avatar: true,
                                      label: text.photoCropAvatar,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                text.photoCropZoom,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(text.photoCropZoomPercent((crop.zoom * 100).round())),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('photo-crop-rotate'),
              onPressed: enabled
                  ? () => widget.onChanged(crop.rotateClockwise())
                  : null,
              tooltip: text.photoCropRotate,
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              key: const Key('photo-crop-reset'),
              onPressed: enabled && !crop.isInitial
                  ? () => widget.onChanged(crop.reset())
                  : null,
              tooltip: text.photoCropReset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const Key('photo-crop-zoom-out'),
              onPressed: enabled && crop.zoom > PhotoCrop.minZoom
                  ? () => widget.onChanged(crop.withZoom(crop.zoom - 0.1))
                  : null,
              tooltip: text.photoCropZoomOut,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Slider(
                key: const Key('photo-crop-zoom'),
                value: crop.zoom,
                min: PhotoCrop.minZoom,
                max: PhotoCrop.maxZoom,
                semanticFormatterCallback: (value) =>
                    text.photoCropZoomPercent((value * 100).round()),
                onChanged: enabled
                    ? (value) => widget.onChanged(crop.withZoom(value))
                    : null,
              ),
            ),
            IconButton(
              key: const Key('photo-crop-zoom-in'),
              onPressed: enabled && crop.zoom < PhotoCrop.maxZoom
                  ? () => widget.onChanged(crop.withZoom(crop.zoom + 0.1))
                  : null,
              tooltip: text.photoCropZoomIn,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
