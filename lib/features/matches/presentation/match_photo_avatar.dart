import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/signed_photo_loader.dart';

/// An authorized thumbnail with the same bounded, in-memory lifetime as the
/// full photo. Never uses Image.network or starts a hidden/background download.
class MatchPhotoAvatar extends StatefulWidget {
  const MatchPhotoAvatar({
    super.key,
    required this.url,
    required this.readAt,
    required this.allowed,
    this.size = 44,
    this.photoClient,
  });

  final String? url;
  final DateTime? readAt;
  final bool allowed;
  final double size;
  final PhotoClientFactory? photoClient;

  @override
  State<MatchPhotoAvatar> createState() => _MatchPhotoAvatarState();
}

class _MatchPhotoAvatarState extends State<MatchPhotoAvatar>
    with WidgetsBindingObserver {
  ImageProvider? _image;
  SignedPhotoDownload? _download;
  Timer? _expiry;
  String? _url;
  int _epoch = 0;
  bool _visible = false;

  bool get _authorized =>
      widget.allowed &&
      widget.url != null &&
      widget.readAt != null &&
      DateTime.now().toUtc().difference(widget.readAt!) < privatePhotoLifetime;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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
  void didUpdateWidget(MatchPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _expiry?.cancel();
    _expiry = null;
    if (_image case final image?) unawaited(image.evict());
    _image = null;
    _url = null;
  }

  void _sync() {
    if (!_authorized || !_visible || !_foreground) {
      _purge();
      return;
    }
    if (_url != widget.url) {
      _purge();
      _url = widget.url;
      unawaited(_fetch(_epoch, _url!));
    }
    _expiry?.cancel();
    final remaining = widget.readAt!
        .add(privatePhotoLifetime)
        .difference(DateTime.now().toUtc());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (mounted) setState(_purge);
    });
  }

  Future<void> _fetch(int epoch, String url) async {
    try {
      final download = SignedPhotoLoader(clientFactory: widget.photoClient)
          .load(url);
      _download = download;
      final bytes = await download.bytes;
      if (!mounted ||
          epoch != _epoch ||
          !_authorized ||
          !_visible ||
          !_foreground) {
        return;
      }
      setState(() => _image = ResizeImage(MemoryImage(bytes), width: 144));
    } catch (_) {
      // The name remains available; a thumbnail failure must not block chat.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purge();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipOval(
      child: SizedBox.square(
        dimension: widget.size,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: _authorized && _image != null
              ? Image(
                  image: _image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(context),
                )
              : _placeholder(context),
        ),
      ),
    ),
  );

  Widget _placeholder(BuildContext context) => Icon(
    Icons.person_outline_rounded,
    color: Theme.of(context).colorScheme.primary,
    size: widget.size * 0.5,
  );
}
