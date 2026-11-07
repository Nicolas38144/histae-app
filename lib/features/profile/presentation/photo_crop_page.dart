import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../data/photo_crop_processor.dart';
import '../domain/photo_crop.dart';
import 'photo_crop_image.dart';
import 'profile_strings.dart';

class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({
    super.key,
    required this.bytes,
    required this.session,
    this.processor,
  });
  final Uint8List bytes;
  final AuthenticatedSession session;
  final PhotoCropProcessor? processor;
  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage>
    with WidgetsBindingObserver {
  late final _owner = widget.session.resourceKey;
  late final _processor = widget.processor ?? PhotoCropProcessor();
  ui.Image? _image;
  PhotoCrop? _crop;
  ApiFailure? _failure;
  bool _loading = true, _saving = false, _foreground = true;
  int _generation = 0;
  double _startZoom = 1;
  Offset _anchor = Offset.zero;
  bool get _allowed =>
      widget.session.resourceKey == _owner &&
      widget.session.hasSession &&
      widget.session.phase == SessionPhase.ready;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final image = await _processor.decode(widget.bytes);
      if (!mounted || !_allowed || generation != _generation) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _crop = PhotoCrop(
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        );
      });
    } on ApiFailure catch (error) {
      if (mounted && _allowed && generation == _generation) {
        setState(() => _failure = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (!_allowed) {
      setState(() {
        _generation++;
        _image?.dispose();
        _image = null;
        _crop = null;
        _loading = false;
        _saving = false;
      });
    } else if (_image == null && !_loading) {
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  Future<void> _finish() async {
    final crop = _crop;
    if (!_allowed ||
        !_foreground ||
        _saving ||
        _image == null ||
        crop == null) {
      return;
    }
    final generation = _generation;
    // Back/logout may dispose the editor while the native encoder is running.
    final image = _image!.clone();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final bytes = await _processor.prepare(image, crop);
      if (mounted && _allowed && _foreground && generation == _generation) {
        Navigator.of(context).pop(bytes);
      }
    } on ApiFailure catch (error) {
      if (mounted && _allowed && generation == _generation) {
        setState(() => _failure = error);
      }
    } finally {
      image.dispose();
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const HistaeScaffold(body: SizedBox.shrink());
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final crop = _crop, image = _image;
    final enabled = !_loading && !_saving && crop != null && image != null;
    return HistaeScaffold(
      appBar: AppBar(title: Text(text.photoCropTitle)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: HistaeButton(
            onPressed: enabled ? _finish : null,
            key: const Key('photo-crop-confirm'),
            child: Text(_saving ? text.photoCropPreparing : text.photoCropUse),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: text.photoCropPreparing,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    text.photoCropInstructions,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  if (image != null && crop != null) ...[
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
                                        _startZoom = _crop!.zoom;
                                        _anchor = _crop!.sourcePoint(
                                          details.localFocalPoint,
                                          viewport,
                                        );
                                      },
                                onScaleUpdate: !enabled
                                    ? null
                                    : (details) => setState(() {
                                        _crop = crop.gesture(
                                          nextZoom: _startZoom * details.scale,
                                          anchor: _anchor,
                                          focalPoint: details.localFocalPoint,
                                          viewport: viewport,
                                        );
                                      }),
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
                                              key: const Key(
                                                'photo-crop-avatar-preview',
                                              ),
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
                        Text(
                          text.photoCropZoomPercent((crop.zoom * 100).round()),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('photo-crop-rotate'),
                          onPressed: enabled
                              ? () => setState(
                                  () => _crop = crop.rotateClockwise(),
                                )
                              : null,
                          tooltip: text.photoCropRotate,
                          icon: const Icon(Icons.rotate_right_rounded),
                        ),
                        IconButton(
                          key: const Key('photo-crop-reset'),
                          onPressed: enabled && !crop.isInitial
                              ? () => setState(() => _crop = crop.reset())
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
                              ? () => setState(
                                  () => _crop = crop.withZoom(crop.zoom - 0.1),
                                )
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
                            semanticFormatterCallback: (value) => text
                                .photoCropZoomPercent((value * 100).round()),
                            onChanged: enabled
                                ? (value) => setState(
                                    () => _crop = crop.withZoom(value),
                                  )
                                : null,
                          ),
                        ),
                        IconButton(
                          key: const Key('photo-crop-zoom-in'),
                          onPressed: enabled && crop.zoom < PhotoCrop.maxZoom
                              ? () => setState(
                                  () => _crop = crop.withZoom(crop.zoom + 0.1),
                                )
                              : null,
                          tooltip: text.photoCropZoomIn,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                  if (_saving)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        semanticsLabel: text.photoCropPreparing,
                      ),
                    ),
                  if (_failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(ProfileStrings(strings).failure(_failure!)),
                      ),
                    ),
                  if (image == null && _failure != null)
                    HistaeButton.text(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(text.photoCropBack),
                    ),
                ],
              ),
      ),
    );
  }
}
