import 'dart:async';

import 'package:flutter/material.dart';

import '../media/private_photo_cache.dart';
import '../network/signed_photo_loader.dart';

typedef PrivatePhotoBuilder = Widget Function(
  BuildContext context,
  ImageProvider? image,
  bool loading,
  bool failed,
);

/// Private image display, never persisted. Full-size bytes are route-owned;
/// thumbnails may use a session cache while authorization remains valid.
/// URL expiry limits new downloads, not display of authorized downloaded pixels.
class PrivatePhoto extends StatefulWidget {
  const PrivatePhoto({
    super.key,
    required this.url,
    required this.readAt,
    required this.allowed,
    required this.decodeWidth,
    required this.builder,
    this.refreshAccess,
    this.photoClient,
    this.memoryCache,
    this.cacheKey,
  }) : assert(memoryCache == null || cacheKey != null);

  final String? url;
  final DateTime? readAt;
  final bool allowed;
  final int decodeWidth;
  final PrivatePhotoBuilder builder;
  final Future<void> Function()? refreshAccess;
  final PhotoClientFactory? photoClient;
  final PrivatePhotoCache? memoryCache;
  final String? cacheKey;

  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto>
    with WidgetsBindingObserver {
  ImageProvider? _image;
  SignedPhotoDownload? _download;
  String? _resource;
  int _epoch = 0;
  bool _visible = false, _loading = false, _failed = false;

  bool get _allowed =>
      widget.allowed &&
      widget.url != null &&
      _visible &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  bool get _fresh =>
      widget.readAt != null &&
      DateTime.now().toUtc().difference(widget.readAt!) < privatePhotoLifetime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _sync();
  }

  @override
  void didUpdateWidget(PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryCache != widget.memoryCache ||
        oldWidget.cacheKey != widget.cacheKey) {
      _purge();
    }
    if (_failed &&
        (oldWidget.url != widget.url || oldWidget.readAt != widget.readAt)) {
      _purge();
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(_sync);
  }

  void _purge() {
    _epoch++;
    _download?.cancel();
    _download = null;
    if (_image case final image?) {
      if (widget.cacheKey == null ||
          widget.memoryCache?.owns(widget.cacheKey!, image) != true) {
        unawaited(image.evict());
      }
    }
    _image = null;
    _resource = null;
    _loading = false;
    _failed = false;
  }

  void _sync() {
    if (!_allowed) {
      _purge();
      return;
    }
    final resource = signedPhotoResource(widget.url!);
    if (_resource == resource) return;
    _purge();
    _resource = resource;
    final cached = widget.cacheKey == null
        ? null
        : widget.memoryCache?.lookup(
            widget.cacheKey!,
            widget.url!,
            widget.decodeWidth,
          );
    if (cached != null) {
      _image = cached;
      return;
    }
    _loading = true;
    // A stale snapshot can be encountered on navigation. Refresh only while
    // visible, once per attempt; controller reads coalesce across avatars.
    unawaited(_load(_epoch));
  }

  bool _alive(int epoch) => mounted && epoch == _epoch && _allowed;

  Future<void> _load(int epoch) async {
    var refreshed = false;
    try {
      if (!_fresh) {
        refreshed = true;
        // Avoid notifying an ancestor during this widget's build.
        await Future<void>.delayed(Duration.zero);
        if (!_alive(epoch)) return;
        await widget.refreshAccess?.call();
        if (!_alive(epoch)) return;
        // A controller notification rebuilds the URL/authorization first.
        await WidgetsBinding.instance.endOfFrame;
        if (!_alive(epoch)) return;
      }
      while (_alive(epoch)) {
        if (!_fresh) throw StateError('Expired photo URL');
        try {
          if (widget.memoryCache case final cache?
              when widget.cacheKey != null) {
            final image = await cache.load(
              key: widget.cacheKey!,
              url: widget.url!,
              width: widget.decodeWidth,
              photoClient: widget.photoClient,
            );
            if (_alive(epoch)) setState(() => _image = image);
            return;
          }
          final request = SignedPhotoLoader(clientFactory: widget.photoClient)
              .load(widget.url!);
          _download = request;
          final bytes = await request.bytes;
          if (!_alive(epoch)) return;
          setState(() {
            _image = ResizeImage(MemoryImage(bytes), width: widget.decodeWidth);
          });
          return;
        } catch (_) {
          if (!_alive(epoch) || refreshed || widget.refreshAccess == null) {
            rethrow;
          }
          refreshed = true;
          await widget.refreshAccess!();
          if (!_alive(epoch)) return;
          await WidgetsBinding.instance.endOfFrame;
        }
      }
    } catch (_) {
      if (_alive(epoch)) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) {
        _download = null;
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purge();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _allowed ? _image : null, _loading, _failed);
}
