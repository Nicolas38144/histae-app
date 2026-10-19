import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../privacy/presentation/report_page.dart';
import '../application/discovery_controller.dart';

class EncounterPage extends StatelessWidget {
  const EncounterPage({
    super.key,
    required this.controller,
    required this.receipt,
    this.openMatch,
  });
  final DiscoveryController controller;
  final EncounterReceipt receipt;
  final Future<void> Function()? openMatch;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.accessible ||
          controller.encounter?.match.id != receipt.match.id) {
        return HistaeScaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.of(context).messages.continuationPageYourMatch,
            ),
          ),
          body: Center(
            child: Text(
              AppStrings.of(context)
                  .messages
                  .encounterPageThisMatchIsNoLongerAvailable,
            ),
          ),
        );
      }
      final created = receipt.match.createdAt.toLocal();
      // This screen acknowledges the server-created match. It does not infer
      // live chat access, continuation or photo revelation from this snapshot.
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(AppStrings.of(context).messages.encounterPageAMatch),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              EditorialCard(
                eyebrow: AppStrings.of(context)
                    .messages
                    .encounterPageMutualInterest,
                title: AppStrings.of(context)
                    .messages
                    .encounterPageWordsBroughtYouTogether,
                body: AppStrings.of(context).messages
                    .encounterPageYouAndChoseEachOtherA(
                      receipt.profile.firstname,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.of(context).messages.encounterPage(
                  receipt.profile.firstname,
                  receipt.profile.age,
                ),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                AppStrings.of(context).messages
                    .matchCreatedOn(AppStrings.of(context).date(created)),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.of(context)
                    .messages
                    .encounterPageYourPhotosStayPrivateThisMatch,
              ),
              const SizedBox(height: 24),
              if (openMatch != null)
                HistaeButton.icon(
                  onPressed: openMatch,
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(
                    AppStrings.of(context)
                        .messages
                        .encounterPageOpenConversation,
                  ),
                ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppStrings.of(context).messages.encounterPageBackToDiscovery,
                ),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        if (!await confirmAction(
                              context,
                              AppStrings.of(context)
                                  .messages
                                  .encounterPageBlockThisPerson,
                              AppStrings.of(context)
                                  .messages
                                  .encounterPageYourMatchWillEndAndYou,
                              action: AppStrings.of(context)
                                  .messages
                                  .discoveryPageBlock,
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        if (!controller.active) await controller.activate();
                        await controller.blockProfile(receipt.profile);
                        if (context.mounted && controller.encounter == null) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text(
                  AppStrings.of(context)
                      .messages
                      .encounterPageBlockThisPerson447,
                ),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReportPage(
                            session: controller.session,
                            target: receipt.profile.id,
                            matchId: receipt.match.id,
                            onBlock: () async {
                              if (!controller.active) {
                                await controller.activate();
                              }
                              await controller.blockProfile(receipt.profile);
                            },
                          ),
                        ),
                      ),
                child: Text(
                  AppStrings.of(context).messages.encounterPageReportThisPerson,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
