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

/// Private image display, never persisted. Callers can supply a session cache
/// while access to the photo remains authorized.
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
    this.keepCachedWhileMuted = false,
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
  final bool keepCachedWhileMuted;

  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto>
    with WidgetsBindingObserver {
  PrivatePhotoCache? _localCache;
  ({PrivatePhotoCache cache, String key, String resource, int width})? _source;
  ImageProvider? _image;
  int _epoch = 0;
  bool _routeCurrent = false, _tickersEnabled = false;
  bool _loading = false, _failed = false;

  bool get _allowed =>
      widget.allowed &&
      widget.url != null &&
      _routeCurrent &&
      (_tickersEnabled || widget.keepCachedWhileMuted) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _sync();
  }

  @override
  void didUpdateWidget(PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_failed &&
        (oldWidget.url != widget.url || oldWidget.readAt != widget.readAt)) {
      _reset();
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(_sync);
  }

  void _reset() {
    _epoch++;
    if (_image case final image?) {
      final source = _source!;
      if (!source.cache.owns(source.key, image)) unawaited(image.evict());
    }
    _localCache?.clear();
    _image = null;
    _source = null;
    _loading = false;
    _failed = false;
  }

  void _sync() {
    if (!_allowed) {
      _reset();
      return;
    }
    final url = widget.url!;
    final source = (
      cache:
          widget.memoryCache ??
          (_localCache ??= PrivatePhotoCache(maxEntries: 1)),
      key: widget.cacheKey ?? 'photo',
      resource: signedPhotoResource(url),
      width: widget.decodeWidth,
    );
    if (_source == source) return;
    _reset();

    final cached = source.cache.lookup(source.key, url, source.width);
    // A tab can still be painted while its tickers are muted.
    if (cached == null && !_tickersEnabled) return;
    _source = source;
    _image = cached;
    if (cached == null) {
      _loading = true;
      unawaited(_load(_epoch));
    }
  }

  bool _alive(int epoch) => mounted && epoch == _epoch && _allowed;

  Future<void> _load(int epoch) async {
    final source = _source!;
    final refresh = widget.refreshAccess;
    ImageProvider? image;
    var failed = false;
    try {
      image = await source.cache.loadWithRenewal(
        key: source.key,
        width: source.width,
        readAccess: () =>
            _alive(epoch) ? (url: widget.url!, readAt: widget.readAt) : null,
        renewAccess: refresh == null ? null : () => _renew(refresh, epoch),
        photoClient: widget.photoClient,
      );
    } catch (_) {
      failed = true;
    }
    if (!_alive(epoch)) return;
    setState(() {
      _image = image;
      _failed = failed;
      _loading = false;
    });
  }

  Future<void> _renew(Future<void> Function() refresh, int epoch) async {
    // Let the current build finish, then give the refreshed URL a chance to rebuild.
    await Future<void>.delayed(Duration.zero);
    if (!_alive(epoch)) return;
    await refresh();
    if (_alive(epoch)) await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reset();
    _localCache?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _allowed ? _image : null, _loading, _failed);
}
