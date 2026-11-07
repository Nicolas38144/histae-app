import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/private_photo.dart';
import '../application/profile_controller.dart';

/// The owner's private photo is shown only in their own preview, never in feed cards.
class ProfileOwnerPhoto extends StatelessWidget {
  const ProfileOwnerPhoto({
    super.key,
    required this.controller,
    this.photoClient,
  });
  final ProfileController controller;
  final PhotoClientFactory? photoClient;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return PrivatePhoto(
      url: controller.profile?.photo,
      readAt: controller.photoReadAt,
      allowed: controller.accessible && controller.hasFeedPreview,
      decodeWidth: 640,
      photoClient: photoClient,
      refreshAccess: controller.refreshPhotoPreview,
      builder: (context, image, loading, failed) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            LinearProgressIndicator(
              semanticsLabel: text.photoPagePreparingOrLoadingPhoto,
            ),
          if (image != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 192,
                  height: 240,
                  child: Image(
                    image: image,
                    fit: BoxFit.contain,
                    semanticLabel: text.photoPageYourCurrentPhoto,
                    errorBuilder: (_, _, _) =>
                        Center(child: Text(text.photoPagePreviewUnavailable)),
                  ),
                ),
              ),
            ),
          if (failed) Text(text.photoPagePreviewUnavailable),
        ],
      ),
    );
  }
}
