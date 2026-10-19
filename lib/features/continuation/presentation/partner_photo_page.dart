import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../profile/data/profile_models.dart';
import '../application/match_access.dart';

class PartnerPhotoPage extends StatefulWidget {
  const PartnerPhotoPage({
    super.key,
    required this.access,
    required this.matchId,
    this.photoClient,
  });
  final MatchAccess access;
  final String matchId;
  final PhotoClientFactory? photoClient;

  @override
  State<PartnerPhotoPage> createState() => _PartnerPhotoPageState();
}

class _PartnerPhotoPageState extends State<PartnerPhotoPage>
    with WidgetsBindingObserver {
  MatchAccess get c => widget.access;
  late final _key = c.session.resourceKey;
  ImageProvider? _image;
  String? _url, _error;
  SignedPhotoDownload? _download;
  Timer? _expiry;
  int _epoch = 0;
  bool _foreground = true, _loading = false;

  bool get _allowed =>
      _foreground &&
      c.active &&
      c.verified &&
      c.session.resourceKey == _key &&
      c.selected?.id == widget.matchId &&
      c.selected!.historyAllowed &&
      c.selected!.photosRevealed &&
      c.readAt != null &&
      DateTime.now().toUtc().difference(c.readAt!) < const Duration(minutes: 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          c.refresh().then((_) {
            if (mounted) _changed();
          }),
        );
      }
    });
  }

  void _purge() {
    _epoch++;
    _download?.cancel();
    _download = null;
    _expiry?.cancel();
    if (_image case final image?) unawaited(image.evict());
    _image = null;
    _url = null;
    _loading = false;
  }

  void _changed() {
    if (!mounted) return;
    final url = _allowed ? c.selected!.partner.photo : null;
    if (!_allowed || url == null) {
      setState(_purge);
      return;
    }
    if (url == _url) return;
    _purge();
    _url = url;
    _error = null;
    _expiry = Timer(const Duration(minutes: 4), () {
      if (!mounted) return;
      setState(_purge);
      unawaited(c.refresh());
    });
    unawaited(_fetch(url));
  }

  Future<void> _fetch(String url) async {
    if (!validPhotoUrl(url) || !_allowed) return;
    final epoch = _epoch;
    final request = SignedPhotoLoader(clientFactory: widget.photoClient)
        .load(url);
    _download = request;
    setState(() {
      _loading = true;
    });
    try {
      final bytes = await request.bytes;
      if (mounted && epoch == _epoch && _allowed && _url == url) {
        setState(() {
          _image = ResizeImage(MemoryImage(bytes), width: 1024);
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = AppStrings.of(context)
              .messages
              .partnerPhotoPageTheTemporaryPhotoIsUnavailableRefresh;
        });
      }
    } finally {
      request.cancel();
      if (mounted && epoch == _epoch) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      setState(_purge);
    } else {
      unawaited(c.refresh());
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _purge();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    appBar: AppBar(
      title: Text(
        AppStrings.of(context).messages.partnerPhotoPageAPhotoTogether,
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_allowed || c.selected?.partner.photo == null)
            Text(
              AppStrings.of(context)
                  .messages
                  .partnerPhotoPageThisPhotoIsCurrentlyUnavailable,
            )
          else ...[
            if (_loading)
              LinearProgressIndicator(
                semanticsLabel: AppStrings.of(context)
                    .messages
                    .partnerPhotoPageLoadingPhoto,
              ),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image(
                    image: _image!,
                    fit: BoxFit.contain,
                    semanticLabel: AppStrings.of(context)
                        .messages
                        .partnerPhotoPageYourMatchSPhoto,
                    errorBuilder: (_, _, _) => Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .partnerPhotoPageThePhotoCannotBeShownRefresh,
                      ),
                    ),
                  ),
                ),
              ),
            if (_error != null) Text(_error!),
            const SizedBox(height: 24),
            Text(
              AppStrings.of(context)
                  .messages
                  .partnerPhotoPageYouBothAgreedToRevealPhotos,
            ),
          ],
          OutlinedButton.icon(
            onPressed: !c.active || _loading
                ? null
                : () async {
                    setState(_purge);
                    await c.refresh();
                    if (mounted) _changed();
                  },
            icon: const Icon(Icons.refresh),
            label: Text(
              AppStrings.of(context).messages.partnerPhotoPageRefreshPhoto,
            ),
          ),
        ],
      ),
    ),
  );
}
