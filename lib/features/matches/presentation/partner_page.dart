import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../continuation/presentation/partner_photo_page.dart';
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
              controller.selected?.historyAllowed == true
          ? controller.selected
          : null;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(
            match?.partner.firstname ??
                AppStrings.of(context).messages.mainNavigationBarProfile,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (match == null)
                Text(
                  AppStrings.of(context)
                      .messages
                      .discoveryStringsThisProfileIsNoLongerAvailable,
                )
              else ...[
                EditorialCard(
                  title: AppStrings.of(context).messages.encounterPage(
                    match.partner.firstname,
                    match.partner.age,
                  ),
                  body:
                      match.partner.bio ??
                      AppStrings.of(context)
                          .messages
                          .partnerPageDiscoverThisPersonThroughYourConversations,
                ),
                const SizedBox(height: 24),
                if (match.photosRevealed && match.partner.photo != null)
                  OutlinedButton.icon(
                    onPressed: !controller.verified
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PartnerPhotoPage(
                                access: controller,
                                matchId: id,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(
                      AppStrings.of(context)
                          .messages
                          .continuationPageViewTheirPhoto,
                    ),
                  ),
                TextButton(
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
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .encounterPageReportThisPerson,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: match.partner.traits
                      .map((t) => Chip(label: Text(t)))
                      .toList(),
                ),
                for (final answer in match.partner.answers) ...[
                  const EditorialDivider(),
                  Text(
                    answer.question,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(answer.answer),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}
