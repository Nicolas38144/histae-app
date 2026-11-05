import 'dart:async';

import 'package:flutter/widgets.dart';

import '../network/api_failure.dart';
import '../network/signed_photo_loader.dart';

/// Foreground-only thumbnail memory, owned by one verified session controller.
/// Full-size photos retain their stricter route-owned lifetime.
class PrivatePhotoCache with WidgetsBindingObserver {
  PrivatePhotoCache({this.maxEntries = 48, this.maxBytes = 8 * 1024 * 1024})
    : assert(maxEntries >= 0),
      assert(maxBytes >= 0);

  final int maxEntries, maxBytes;
  final _entries = <String, _PhotoEntry>{};
  final _pending = <String, _PhotoLoad>{};
  int _bytes = 0;
  bool _observing = false, _disposed = false;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _observe() {
    if (!_observing && !_disposed) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  ImageProvider? lookup(String key, String url, int width) {
    _observe();
    if (_disposed || !_foreground) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.resource != signedPhotoResource(url) || entry.width != width) {
      invalidate(key);
      return null;
    }
    _entries.remove(key);
    _entries[key] = entry;
    return entry.image;
  }

  bool owns(String key, ImageProvider image) =>
      identical(_entries[key]?.image, image);

  Future<ImageProvider> load({
    required String key,
    required String url,
    required int width,
    PhotoClientFactory? photoClient,
  }) {
    final existing = lookup(key, url, width);
    if (existing != null) return Future.value(existing);
    if (_disposed || !_foreground) {
      return Future.error(const ApiFailure(ApiFailureKind.cancelled));
    }
    final resource = signedPhotoResource(url);
    final pending = _pending[key];
    if (pending != null &&
        pending.resource == resource &&
        pending.width == width) {
      return pending.result;
    }
    invalidate(key);
    final request = SignedPhotoLoader(clientFactory: photoClient).load(url);
    final task = _PhotoLoad(resource, width, request);
    _pending[key] = task;
    task.result = _read(key, task);
    return task.result;
  }

  Future<ImageProvider> _read(String key, _PhotoLoad task) async {
    try {
      final bytes = await task.request.bytes;
      if (_disposed || !_foreground || !identical(_pending[key], task)) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      final image = ResizeImage(MemoryImage(bytes), width: task.width);
      if (bytes.length <= maxBytes && maxEntries > 0) {
        _entries[key] = _PhotoEntry(
          task.resource,
          task.width,
          image,
          bytes.length,
        );
        _bytes += bytes.length;
        while (_entries.length > maxEntries || _bytes > maxBytes) {
          _evict(_entries.keys.first);
        }
      }
      return image;
    } finally {
      if (identical(_pending[key], task)) _pending.remove(key);
    }
  }

  void _evict(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return;
    _bytes -= entry.bytes;
    unawaited(entry.image.evict());
  }

  void invalidate(String key) {
    _pending.remove(key)?.request.cancel();
    _evict(key);
  }

  /// Only the controller decides which current server grants remain usable.
  void retainAuthorized(Map<String, String> photos) {
    for (final key in {..._entries.keys, ..._pending.keys}) {
      final url = photos[key];
      final resource = _entries[key]?.resource ?? _pending[key]?.resource;
      if (url == null || signedPhotoResource(url) != resource) invalidate(key);
    }
  }

  void clear() {
    for (final key in {..._entries.keys, ..._pending.keys}) {
      invalidate(key);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) clear();
  }

  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    clear();
  }
}

class _PhotoEntry {
  const _PhotoEntry(this.resource, this.width, this.image, this.bytes);
  final String resource;
  final int width, bytes;
  final ImageProvider image;
}

class _PhotoLoad {
  _PhotoLoad(this.resource, this.width, this.request);
  final String resource;
  final int width;
  final SignedPhotoDownload request;
  late final Future<ImageProvider> result;
}
