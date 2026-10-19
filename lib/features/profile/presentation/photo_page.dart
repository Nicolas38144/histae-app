import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/profile_controller.dart';
import '../data/photo_preparer.dart';
import '../data/profile_models.dart';
import 'profile_strings.dart';

class PhotoPage extends StatefulWidget {
  const PhotoPage({
    super.key,
    required this.controller,
    this.preparer,
    this.photoClient,
  });
  final ProfileController controller;
  final PhotoPreparer? preparer;
  final PhotoClientFactory? photoClient;

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> with WidgetsBindingObserver {
  ProfileController get c => widget.controller;
  late final preparer = widget.preparer ?? PhotoPreparer();
  late final String _ownerScope = c.session.resourceKey;
  Uint8List? _remote;
  String? _url;
  String Function(AppStrings)? _message;
  DateTime? _readAt;
  SignedPhotoDownload? _download;
  Timer? _expiry;
  bool _choosing = false, _fetching = false, _active = true;
  int _downloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    unawaited(_recover());
    unawaited(
      c.load().then((_) {
        if (mounted) _changed();
      }),
    );
  }

  Future<void> _recover() async {
    try {
      if (await preparer.discardInterruptedSelection() && mounted) {
        setState(() {
          _message = (strings) =>
              strings.messages.photoPageSelectionWasInterruptedChooseYourPhoto;
        });
      }
    } catch (_) {
      /* Selection still works if Android recovery is unavailable. */
    }
  }

  void _purgeRemote() {
    _downloadGeneration++;
    _download?.cancel();
    _download = null;
    if (_remote case final bytes?) unawaited(MemoryImage(bytes).evict());
    _remote = null;
    _url = null;
    _readAt = null;
    _fetching = false;
    _expiry?.cancel();
  }

  void _changed() {
    if (!mounted) return;
    if (!c.accessible || c.session.resourceKey != _ownerScope) {
      setState(_purgeRemote);
      return;
    }
    if (!_active) return;
    if (c.loading) {
      setState(() {});
      return;
    }
    final url = c.profile?.photo;
    if (url != _url || c.photoReadAt != _readAt) {
      _purgeRemote();
      _url = url;
      _readAt = c.photoReadAt;
      // Owner URLs last 300 s in the server contract. Refresh before expiry,
      // including when the signer happens to return the same URL.
      final age = DateTime.now().difference(
        _readAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      final remaining = const Duration(minutes: 4) - age;
      if (remaining > Duration.zero && url != null) {
        _expiry = Timer(remaining, () {
          if (mounted) {
            setState(_purgeRemote);
            unawaited(c.load());
          }
        });
        unawaited(_fetch(url));
      }
    }
    setState(() {});
  }

  Future<void> _fetch(String url) async {
    if (!validPhotoUrl(url)) return;
    final generation = _downloadGeneration;
    final request = SignedPhotoLoader(clientFactory: widget.photoClient)
        .load(url);
    _download = request;
    _fetching = true;
    try {
      final bytes = await request.bytes;
      if (mounted &&
          _active &&
          generation == _downloadGeneration &&
          c.accessible &&
          c.session.resourceKey == _ownerScope) {
        setState(() {
          _remote = bytes;
        });
      }
    } catch (_) {
      if (mounted && generation == _downloadGeneration) {
        setState(() {
          _message = (strings) =>
              strings.messages.photoPageTheTemporaryPreviewIsUnavailableRefresh;
        });
      }
    } finally {
      request.cancel();
      if (mounted && generation == _downloadGeneration) {
        setState(() {
          _fetching = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      setState(_purgeRemote);
    } else {
      unawaited(
        c.load().then((_) {
          if (mounted) _changed();
        }),
      );
    }
  }

  Future<void> _choose() async {
    if (_choosing || !c.canWrite) return;
    if (c.photoIntent != null &&
        !await confirmAction(
          context,
          AppStrings.of(context).messages.photoPageChangeSelection,
          AppStrings.of(context).messages.photoPageTheSavedPhotoRequestWillBe,
          action: AppStrings.of(context).messages.photoPageChooseAnotherPhoto,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _choosing = true;
      _message = null;
    });
    try {
      final bytes = await preparer.choose();
      if (mounted &&
          c.accessible &&
          c.session.resourceKey == _ownerScope &&
          bytes != null) {
        c.setPhoto(bytes);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _message = (strings) => ProfileStrings(strings).failure(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _choosing = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    try {
      await c.upload();
      if (mounted) {
        setState(() {
          _message = (strings) =>
              strings.messages.photoPagePhotoReceivedItsReviewStatusIs;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _message = (strings) => ProfileStrings(strings).failure(e);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    _purgeRemote();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _ownerScope) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final intent = c.photoIntent;
      final preview = intent == null ? _remote : intent.bytes;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(AppStrings.of(context).messages.photoPageYourPhoto),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                AppStrings.of(context).messages.photoPageAFaceAtTheRightTime,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.of(context)
                    .messages
                    .photoPageOnePersonalPhotoItDoesNot,
              ),
              const SizedBox(height: 24),
              if (preview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.memory(
                    preview,
                    height: 320,
                    fit: BoxFit.contain,
                    semanticLabel: intent == null
                        ? AppStrings.of(context)
                              .messages
                              .photoPageYourCurrentPhoto
                        : AppStrings.of(context)
                              .messages
                              .photoPageYourSelectionNotYetConfirmedBy,
                    errorBuilder: (_, _, _) => SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          AppStrings.of(context)
                              .messages
                              .photoPagePreviewUnavailable,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_fetching || _choosing || c.saving || c.loading)
                LinearProgressIndicator(
                  semanticsLabel: AppStrings.of(context)
                      .messages
                      .photoPagePreparingOrLoadingPhoto,
                ),
              if (c.profile?.photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    AppStrings.of(context).messages.photoPageCurrentPhoto(
                      ProfileStrings(AppStrings.of(context))
                          .moderation(c.profile!.photoModeration),
                    ),
                  ),
                ),
              if (intent != null)
                Text(
                  AppStrings.of(context).messages
                      .photoPagePreparedSelectionBytesItWillReplace(
                        intent.bytes.length,
                      ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_message!(AppStrings.of(context))),
                  ),
                ),
              if (c.uncertain)
                Text(
                  AppStrings.of(context)
                      .messages
                      .photoPageTheUploadMayHaveSucceededResuming,
                ),
              if (c.retrySeconds > 0)
                Text(
                  AppStrings.of(context).messages
                      .appStringsTryAgainInS(c.retrySeconds),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: !c.canWrite || _choosing ? null : _choose,
                child: Text(
                  intent == null && c.profile?.photo == null
                      ? AppStrings.of(context).messages.photoPageChooseAPhoto
                      : AppStrings.of(context)
                            .messages
                            .photoPageChooseAnotherPhoto,
                ),
              ),
              if (intent != null) ...[
                const SizedBox(height: 12),
                HistaeButton(
                  onPressed:
                      _choosing || c.saving || c.loading || c.retrySeconds > 0
                      ? null
                      : _upload,
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .photoPageSendOrResumeThisPhoto,
                  ),
                ),
              ],
              TextButton(
                onPressed: c.loading || c.saving || c.retrySeconds > 0
                    ? null
                    : () async {
                        _purgeRemote();
                        await c.load();
                        if (mounted) _changed();
                      },
                child: Text(
                  AppStrings.of(context)
                      .messages
                      .photoPageRefreshPhotoAndStatus,
                ),
              ),
              if (c.profile?.photo != null)
                TextButton(
                  onPressed: !c.canWrite || _choosing
                      ? null
                      : () async {
                          if (!await confirmAction(
                                context,
                                AppStrings.of(context)
                                    .messages
                                    .photoPageRemoveYourPhoto,
                                AppStrings.of(context)
                                    .messages
                                    .photoPageThePhotoWillNoLongerBe,
                                action: AppStrings.of(context)
                                    .messages
                                    .photoPageRemovePhoto,
                              ) ||
                              !mounted) {
                            return;
                          }
                          try {
                            await c.removePhoto();
                          } on ApiFailure catch (e) {
                            if (mounted) {
                              setState(() {
                                _message = (strings) =>
                                    ProfileStrings(strings).failure(e);
                              });
                            }
                          }
                        },
                  child: Text(
                    AppStrings.of(context).messages.photoPageRemoveMyPhoto,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
