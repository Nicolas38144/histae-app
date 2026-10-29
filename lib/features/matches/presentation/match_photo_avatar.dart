import 'package:flutter/material.dart';

import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/private_photo.dart';

/// A private thumbnail using the same route-scoped loader as the full photo.
class MatchPhotoAvatar extends StatelessWidget {
  const MatchPhotoAvatar({
    super.key,
    required this.url,
    required this.readAt,
    required this.allowed,
    this.size = 44,
    this.photoClient,
    this.refreshAccess,
  });

  final String? url;
  final DateTime? readAt;
  final bool allowed;
  final double size;
  final PhotoClientFactory? photoClient;
  final Future<void> Function()? refreshAccess;

  @override
  Widget build(BuildContext context) => PrivatePhoto(
    url: url,
    readAt: readAt,
    allowed: allowed,
    decodeWidth: 144,
    photoClient: photoClient,
    refreshAccess: refreshAccess,
    builder: (context, image, loading, failed) => ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.12),
            child: image != null
                ? Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(context),
                  )
                : _placeholder(context),
          ),
        ),
      ),
    ),
  );

  Widget _placeholder(BuildContext context) => Icon(
    Icons.person_outline_rounded,
    color: Theme.of(context).colorScheme.primary,
    size: size * 0.5,
  );
}
