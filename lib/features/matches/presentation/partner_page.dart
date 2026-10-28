import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../continuation/presentation/partner_photo.dart';
import '../../discovery/presentation/feed_profile_content.dart';
import '../../privacy/presentation/report_page.dart';
import '../application/matches_controller.dart';

class PartnerPage extends StatelessWidget {
  const PartnerPage({super.key, required this.controller, required this.id});
  final MatchesController controller;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final match =
          controller.selectedId == id &&
              controller.accessible &&
              controller.selected?.lifecycle.allowsHistoryAt(
                    controller.serverNow,
                  ) ==
                  true
          ? controller.selected
          : null;
      final text = AppStrings.of(context).messages;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(
            match?.partner.firstname ?? text.mainNavigationBarProfile,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (match == null)
                Text(text.discoveryStringsThisProfileIsNoLongerAvailable)
              else ...[
                if (match.photosRevealed && !controller.photosBlocked(id)) ...[
                  PartnerPhoto(access: controller, matchId: id),
                  const SizedBox(height: 24),
                ],
                FeedProfileContent(
                  firstname: match.partner.firstname,
                  age: match.partner.age,
                  bio: match.partner.bio,
                  traits: match.partner.traits,
                  answers: match.partner.answers,
                ),
                const EditorialDivider(),
                HistaeButton.text(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportPage(
                        session: controller.session,
                        target: match.partner.id,
                        matchId: id,
                        onBlock: () => controller.endCurrent(block: true),
                      ),
                    ),
                  ),
                  child: Text(text.encounterPageReportThisPerson),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
