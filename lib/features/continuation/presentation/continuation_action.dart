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
class ContinuationAction extends StatefulWidget {
  const ContinuationAction({
    super.key,
    required this.controller,
    required this.matchId,
    this.catalog,
    this.showFeedback = true,
    this.onProgressChanged,
  });

  final ContinuationController controller;
  final String matchId;
  final CatalogRepository? catalog;
  final bool showFeedback;
  final ValueChanged<bool>? onProgressChanged;

  @override
  State<ContinuationAction> createState() => _ContinuationActionState();
}

class _ContinuationActionState extends State<ContinuationAction>
    with AutomaticKeepAliveClientMixin<ContinuationAction> {
  bool _working = false;

  @override
  bool get wantKeepAlive => _working;

  Future<T> _withProgress<T>(Future<T> Function() operation) async {
    final onProgressChanged = widget.onProgressChanged;
    setState(() => _working = true);
    updateKeepAlive();
    onProgressChanged?.call(true);
    try {
      return await operation();
    } finally {
      if (mounted) {
        setState(() => _working = false);
        updateKeepAlive();
      }
      onProgressChanged?.call(false);
    }
  }

  Future<void> _continue() async {
    final c = widget.controller, owner = c.access.session.resourceKey;
    final matchId = widget.matchId;
    if (_working || !c.canContinue || c.match?.id != matchId) return;
    if (c.pendingCost != null) {
      await _withProgress(c.resumeContinuation);
      return;
    }
    final offer = await _withProgress(c.prepareContinuation);
    if (!mounted ||
        c.access.session.resourceKey != owner ||
        c.match?.id != matchId) {
      return;
    }
    if (offer == null) {
      if (c.canContinue &&
          c.quotaReadAt != null &&
          c.quota?.canStart == false) {
        await openContinuationCredits(
          context,
          controller: c,
          catalog: widget.catalog,
        );
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
        mounted &&
        c.access.session.resourceKey == owner &&
        c.match?.id == matchId) {
      await _withProgress(() => c.accept(offer));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.access,
      ]),
      builder: (context, _) {
        final c = widget.controller, strings = AppStrings.of(context);
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
              onPressed:
                  !_working && c.canContinue && c.match?.id == widget.matchId
                  ? _continue
                  : null,
              icon: _working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      waiting ? Icons.hourglass_empty : Icons.bookmark_outline,
                    ),
              label: Text(label),
            ),
            if (widget.showFeedback) ...[
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
}
