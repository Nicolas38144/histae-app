import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../catalog/data/catalog_repository.dart';
import '../application/continuation_controller.dart';
import 'continuation_strings.dart';
import 'credits_page.dart';

Future<void> openContinuationCredits(
  BuildContext context, {
  required ContinuationController controller,
  CatalogRepository? catalog,
}) async {
  final owner = controller.access.session.resourceKey;
  final route = MaterialPageRoute<void>(
    builder: (_) => CreditsPage(
      controller: controller,
      catalog: catalog,
      focusVideo: controller.quota?.suggestsRewardedVideo == true,
    ),
  );
  await Navigator.of(context).push(route);
  await route.completed;
  if (context.mounted && controller.access.session.resourceKey == owner) {
    await controller.activate();
  }
}

/// Shares the confirmed cost/retry flow between chat and match details.
class ContinuationAction extends StatelessWidget {
  const ContinuationAction({
    super.key,
    required this.controller,
    required this.matchId,
    this.catalog,
    this.showFeedback = true,
  });

  final ContinuationController controller;
  final String matchId;
  final CatalogRepository? catalog;
  final bool showFeedback;

  Future<void> _continue(BuildContext context) async {
    final c = controller, owner = controller.access.session.resourceKey;
    if (!c.canContinue || c.match?.id != matchId) return;
    if (c.pendingCost != null) {
      await c.resumeContinuation();
      return;
    }
    final offer = await c.prepareContinuation();
    if (!context.mounted ||
        c.access.session.resourceKey != owner ||
        c.match?.id != matchId) {
      return;
    }
    if (offer == null) {
      if (c.canContinue &&
          c.quotaReadAt != null &&
          c.quota?.canStart == false) {
        await openContinuationCredits(context, controller: c, catalog: catalog);
      }
      return;
    }
    final text = AppStrings.of(context).messages;
    final accepted = await confirmAction(
      context,
      text.continuationPageContinueThisMatch,
      offer.cost == 0
          ? text.continuationPageYourCurrentPlanRequiresNoCredit
          : text.continuationPageYouAcceptAMaximumCostOf,
      action: offer.cost == 0
          ? text.continuationPageContinueWithoutCredits
          : text.continuationPageAcceptUpTo1Credit,
    );
    if (accepted &&
        context.mounted &&
        c.access.session.resourceKey == owner &&
        c.match?.id == matchId) {
      await c.accept(offer);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.access]),
    builder: (context, _) {
      final c = controller, strings = AppStrings.of(context);
      final text = strings.messages;
      final waiting = c.myContinued;
      final label = waiting
          ? text.chatContinuationWaiting
          : c.pendingCost != null
          ? text.continuationPageResumeTheSameAgreement
          : c.quotaReadAt != null && c.quota?.canStart == false
          ? text.continuationPageViewMyCredits
          : c.quota?.premium == true
          ? text.continuationPageContinueWithoutCredits
          : text.chatContinuationSpendCredit;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HistaeButton.icon(
            key: const Key('continue-conversation'),
            onPressed: c.canContinue && c.match?.id == matchId
                ? () => _continue(context)
                : null,
            icon: c.busy || c.loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    waiting ? Icons.hourglass_empty : Icons.bookmark_outline,
                  ),
            label: Text(label),
          ),
          if (showFeedback) ...[
            if (c.failure case final error?)
              Text(ContinuationStrings(strings).failure(error)),
            if (c.notice == 'cost_changed')
              Text(text.continuationPageTheCostMustBeCheckedAnd),
            if (c.retrySeconds > 0)
              Text(text.appStringsTryAgainInS(c.retrySeconds)),
          ],
        ],
      );
    },
  );
}
