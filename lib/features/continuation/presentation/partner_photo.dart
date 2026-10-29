import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/private_photo.dart';
import '../application/match_access.dart';

/// Retains the route-owned image when a profile's sliver scrolls off screen.
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
    with AutomaticKeepAliveClientMixin {
  late final _resourceKey = widget.access.session.resourceKey;
  int _attempt = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.access,
      builder: (context, _) {
        final access = widget.access;
        final match = access.selected;
        final allowed =
            access.active &&
            access.verified &&
            access.session.resourceKey == _resourceKey &&
            match?.id == widget.matchId &&
            match!.lifecycle.allowsHistoryAt(access.serverNow) &&
            match.photosRevealed &&
            !access.photosBlocked(widget.matchId);
        final text = AppStrings.of(context).messages;
        return PrivatePhoto(
          key: ValueKey((_resourceKey, widget.matchId, _attempt)),
          url: match?.partner.photo,
          readAt: access.readAt,
          allowed: allowed,
          decodeWidth: 1024,
          photoClient: widget.photoClient,
          refreshAccess: access.refreshPhotos,
          builder: (context, image, loading, failed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allowed || match.partner.photo == null)
                Text(text.partnerPhotoPageThisPhotoIsCurrentlyUnavailable)
              else ...[
                if (loading)
                  LinearProgressIndicator(
                    semanticsLabel: text.partnerPhotoPageLoadingPhoto,
                  ),
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Image(
                        image: image,
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
                if (failed)
                  Text(
                    text.partnerPhotoPageTheTemporaryPhotoIsUnavailableRefresh,
                  ),
              ],
              HistaeButton.outlinedIcon(
                onPressed: !access.active || loading
                    ? null
                    : () async {
                        await access.refreshPhotos();
                        if (mounted) setState(() => _attempt++);
                      },
                icon: const Icon(Icons.refresh),
                label: Text(text.partnerPhotoPageRefreshPhoto),
              ),
            ],
          ),
        );
      },
    );
  }
}
