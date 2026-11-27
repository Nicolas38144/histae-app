import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';

/// Uses the same contain/center-cover fits as revealed profiles and match avatars.
class PhotoSelectionPreview extends StatelessWidget {
  const PhotoSelectionPreview({
    super.key,
    required this.image,
    required this.label,
  });
  final ImageProvider image;
  final String label;
  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    const avatarSize = 64.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image(
              image: image,
              height: 320,
              fit: BoxFit.contain,
              semanticLabel: label,
              errorBuilder: (_, _, _) => Text(text.photoPagePreviewUnavailable),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            ClipOval(
              child: Image(
                image: image,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.square(
                  dimension: avatarSize,
                  child: Icon(Icons.person_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: HistaeTokens.contentSpacing),
            Expanded(child: Text(text.photoCropAvatar)),
          ],
        ),
      ],
    );
  }
}
