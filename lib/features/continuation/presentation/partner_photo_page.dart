import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/match_access.dart';
import 'partner_photo.dart';

class PartnerPhotoPage extends StatelessWidget {
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
          PartnerPhoto(
            access: access,
            matchId: matchId,
            photoClient: photoClient,
          ),
        ],
      ),
    ),
  );
}
