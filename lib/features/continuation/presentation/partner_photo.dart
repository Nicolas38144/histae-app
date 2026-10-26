import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/match_access.dart';

/// Full-size private photo, shared by the profile and the dedicated photo page.
/// Downloaded bytes live only while this route is visible and access is valid.
class PartnerPhoto extends StatefulWidget {
  const PartnerPhoto({
    super.key,
    required this.access,
    required this.matchId,
    this.photoClient,
  });

  final MatchAccess access;
  final String matchId;
  final PhotoClientFactory? photoClient;

  @override
  State<PartnerPhoto> createState() => _PartnerPhotoState();
}

class _PartnerPhotoState extends State<PartnerPhoto>
    with WidgetsBindingObserver {
  late final _resourceKey = widget.access.session.resourceKey;
  ImageProvider? _image;
  SignedPhotoDownload? _download;
  Timer? _expiry;
  String? _url;
  int _epoch = 0;
  bool _visible = false, _loading = false, _failed = false;

  MatchAccess get access => widget.access;

  bool get _allowed =>
      _visible &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      access.active &&
      access.verified &&
      access.session.resourceKey == _resourceKey &&
      access.selected?.id == widget.matchId &&
      access.selected!.historyAllowed &&
      access.selected!.photosRevealed &&
      !access.photosBlocked(widget.matchId) &&
      access.readAt != null &&
      DateTime.now().toUtc().difference(access.readAt!) < privatePhotoLifetime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    access.addListener(_changed);
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
  void didUpdateWidget(PartnerPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.access != access) {
      oldWidget.access.removeListener(_changed);
      access.addListener(_changed);
    }
    if (oldWidget.access != access || oldWidget.matchId != widget.matchId) {
      _purge();
    }
    _sync();
  }

  void _changed() {
    if (mounted) setState(_sync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _changed();

  void _purge() {
    _epoch++;
    _download?.cancel();
    _download = null;
    _expiry?.cancel();
    _expiry = null;
    if (_image case final image?) unawaited(image.evict());
    _image = null;
    _url = null;
    _loading = false;
    _failed = false;
  }

  void _sync() {
    final url = _allowed ? access.selected!.partner.photo : null;
    if (url == null) {
      _purge();
      return;
    }
    if (_url != url) {
      _purge();
      _url = url;
      _loading = true;
      unawaited(_fetch(_epoch, url));
    }
    _expiry?.cancel();
    final remaining = access.readAt!
        .add(privatePhotoLifetime)
        .difference(DateTime.now().toUtc());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (mounted) setState(_purge);
    });
  }

  Future<void> _fetch(int epoch, String url) async {
    SignedPhotoDownload? request;
    try {
      request = SignedPhotoLoader(clientFactory: widget.photoClient).load(url);
      _download = request;
      final bytes = await request.bytes;
      if (mounted && epoch == _epoch && _allowed && _url == url) {
        setState(() => _image = ResizeImage(MemoryImage(bytes), width: 1024));
      }
    } catch (_) {
      if (mounted && epoch == _epoch && _allowed) {
        setState(() => _failed = true);
      }
    } finally {
      request?.cancel();
      if (mounted && epoch == _epoch) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(_purge);
    await access.refresh();
    _changed();
  }

  @override
  void dispose() {
    access.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _purge();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_allowed || access.selected?.partner.photo == null)
          Text(text.partnerPhotoPageThisPhotoIsCurrentlyUnavailable)
        else ...[
          if (_loading)
            LinearProgressIndicator(
              semanticsLabel: text.partnerPhotoPageLoadingPhoto,
            ),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image(
                  image: _image!,
                  fit: BoxFit.contain,
                  semanticLabel: text.partnerPhotoPageYourMatchSPhoto,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      text.partnerPhotoPageThePhotoCannotBeShownRefresh,
                    ),
                  ),
                ),
              ),
            ),
          if (_failed)
            Text(text.partnerPhotoPageTheTemporaryPhotoIsUnavailableRefresh),
        ],
        HistaeButton.outlinedIcon(
          onPressed: !access.active || _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(text.partnerPhotoPageRefreshPhoto),
        ),
      ],
    );
  }
}
