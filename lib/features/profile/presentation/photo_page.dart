import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/private_photo.dart';
import '../application/profile_controller.dart';
import '../data/photo_crop_processor.dart';
import '../data/photo_preparer.dart';
import 'photo_crop_page.dart';
import 'photo_selection_preview.dart';
import 'profile_strings.dart';

class PhotoPage extends StatefulWidget {
  const PhotoPage({
    super.key,
    required this.controller,
    this.preparer,
    this.cropProcessor,
    this.photoClient,
  });
  final ProfileController controller;
  final PhotoPreparer? preparer;
  final PhotoCropProcessor? cropProcessor;
  final PhotoClientFactory? photoClient;

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  ProfileController get c => widget.controller;
  late final preparer = widget.preparer ?? PhotoPreparer();
  late final String _ownerScope = c.session.resourceKey;
  bool get _canAccessPhoto =>
      c.accessible && c.session.resourceKey == _ownerScope;

  String Function(AppStrings)? _message;
  bool _choosing = false;
  int _previewAttempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_recover());
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

  Future<void> _choose(PhotoSource source) async {
    if (_choosing || !c.canWrite) return;
    if (c.photoIntent != null) {
      final text = AppStrings.of(context).messages;
      if (!await confirmAction(
        context,
        text.photoPageChangeSelection,
        text.photoPageTheSavedPhotoRequestWillBe,
        action: text.photoPageChooseAnotherPhoto,
      )) {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _choosing = true;
      _message = null;
    });
    try {
      final bytes = await preparer.choose(source: source);
      if (!mounted || !_canAccessPhoto || bytes == null) return;
      final prepared = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => PhotoCropPage(
            bytes: bytes,
            session: c.session,
            processor: widget.cropProcessor,
          ),
        ),
      );
      if (mounted && _canAccessPhoto && prepared != null) {
        c.setPhoto(prepared);
      }
    } on ApiFailure catch (failure) {
      _showFailure(failure);
    } finally {
      if (mounted) {
        setState(() {
          _choosing = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    setState(() => _message = null);
    try {
      await c.upload();
    } on ApiFailure catch (failure) {
      _showFailure(failure);
    }
  }

  void _showFailure(ApiFailure failure) {
    if (!mounted) return;
    setState(() {
      _message = (strings) => ProfileStrings(strings).failure(failure);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!_canAccessPhoto) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final strings = AppStrings.of(context);
      final text = strings.messages;
      final intent = c.photoIntent;

      return HistaeScaffold(
        appBar: AppBar(title: Text(text.photoPageYourPhoto)),
        body: SafeArea(
          child: ListView(
            padding: HistaeTokens.pagePadding,
            children: [
              Text(
                text.photoPageAFaceAtTheRightTime,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              Text(text.photoPageOnePersonalPhotoItDoesNot),
              const SizedBox(height: HistaeTokens.sectionSpacing),
              PrivatePhoto(
                key: ValueKey((c.photoRevision, _previewAttempt)),
                url: c.profile?.photo,
                readAt: c.photoReadAt,
                allowed: intent == null,
                decodeWidth: ProfileController.ownerPreviewPhotoWidth,
                photoClient: widget.photoClient,
                memoryCache: c.ownerPreviewPhotos,
                cacheKey: ProfileController.ownerPreviewPhotoKey,
                refreshAccess: c.refreshPhotoPreview,
                builder: (context, image, loading, failed) {
                  final preview = intent == null
                      ? image
                      : MemoryImage(intent.bytes);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (preview != null)
                        PhotoSelectionPreview(
                          image: preview,
                          label: intent == null
                              ? text.photoPageYourCurrentPhoto
                              : text.photoPageYourSelectionNotYetConfirmedBy,
                        ),
                      if (loading || _choosing || c.saving || c.loading)
                        LinearProgressIndicator(
                          semanticsLabel: text.photoPagePreparingOrLoadingPhoto,
                        ),
                      if (failed) ...[
                        const SizedBox(height: HistaeTokens.contentSpacing),
                        Text(
                          text.photoPageTheTemporaryPreviewIsUnavailableRefresh,
                        ),
                        if (!c.uncertain)
                          HistaeButton.text(
                            onPressed: c.canWrite
                                ? () => setState(() => _previewAttempt++)
                                : null,
                            child: Text(text.photoPageRefreshPhoto),
                          ),
                      ],
                    ],
                  );
                },
              ),
              if (intent != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: HistaeTokens.contentSpacing,
                  ),
                  child: Text(text.photoCropSelectionReady),
                ),
              if (_message case final message?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(message(strings)),
                  ),
                ),
              if (c.uncertain)
                Text(text.photoPageTheUploadMayHaveSucceededResuming),
              if (c.retrySeconds > 0)
                Text(text.appStringsTryAgainInS(c.retrySeconds)),
              const SizedBox(height: HistaeTokens.sectionSpacing),
              if (intent != null) ...[
                const SizedBox(height: HistaeTokens.textSpacing),
                HistaeButton(
                  onPressed:
                      _choosing || c.saving || c.loading || c.retrySeconds > 0
                      ? null
                      : _upload,
                  child: Text(
                    c.uncertain
                        ? text.photoCropResumeUpload
                        : text.photoCropSavePhoto,
                  ),
                ),
              ],
              HistaeButton.outlinedIcon(
                onPressed: !c.canWrite || _choosing
                    ? null
                    : () => _choose(PhotoSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(text.photoPageTakeAPhoto),
              ),
              HistaeButton.outlined(
                onPressed: !c.canWrite || _choosing
                    ? null
                    : () => _choose(PhotoSource.gallery),
                child: Text(
                  intent == null && c.profile?.photo == null
                      ? text.photoPageChooseAPhoto
                      : text.photoPageChooseAnotherPhoto,
                ),
              ),
              if (c.uncertain)
                HistaeButton.text(
                  onPressed: c.loading || c.saving || c.retrySeconds > 0
                      ? null
                      : c.load,
                  child: Text(text.photoPageRefreshPhoto),
                ),
              if (c.profile?.photo != null)
                HistaeButton.text(
                  onPressed: !c.canWrite || _choosing
                      ? null
                      : () async {
                          if (!await confirmAction(
                                context,
                                text.photoPageRemoveYourPhoto,
                                text.photoPageThePhotoWillNoLongerBe,
                                action: text.photoPageRemovePhoto,
                              ) ||
                              !mounted) {
                            return;
                          }
                          try {
                            await c.removePhoto();
                          } on ApiFailure catch (failure) {
                            _showFailure(failure);
                          }
                        },
                  child: Text(text.photoPageRemoveMyPhoto),
                ),
            ],
          ),
        ),
      );
    },
  );
}
