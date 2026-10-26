import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/continuation_controller.dart';

/// Presentation of the two independent photo choices. The controller owns
/// permission, uncertainty and the server-confirmed state.
class PhotoRevealPanel extends StatelessWidget {
  const PhotoRevealPanel({
    super.key,
    required this.controller,
    required this.onReveal,
    required this.onWithdraw,
    required this.onOpen,
  });

  final ContinuationController controller;
  final VoidCallback onReveal, onWithdraw, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final text = AppStrings.of(context).messages;
    final shared =
        c.match!.photosRevealed && !c.access.photosBlocked(c.match!.id);
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(shared),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    shared
                        ? Icons.favorite_outline_rounded
                        : Icons.photo_outlined,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              text.photoRevealTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(text.photoRevealBody),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.pendingWithdrawal) ...[
                    Text(text.photoRevealWithdrawalPending),
                    const SizedBox(height: 14),
                    HistaeButton(
                      onPressed: c.canWithdrawReveal ? c.withdrawReveal : null,
                      child: Text(text.photoRevealRetryWithdrawal),
                    ),
                  ] else if (shared) ...[
                    Text(text.photoRevealShared),
                    const SizedBox(height: 16),
                    if (c.match!.partner.photo != null)
                      HistaeButton.icon(
                        onPressed: c.access.verified ? onOpen : null,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(text.continuationPageViewTheirPhoto),
                      )
                    else
                      Text(text.continuationPageThePhotoIsCurrentlyUnavailable),
                  ] else if (c.myRevealed) ...[
                    Text(text.photoRevealWaiting),
                  ] else if (c.pendingReveal) ...[
                    Text(text.continuationPageYourPhotoRevealRequestStillNeeds),
                    const SizedBox(height: 14),
                    HistaeButton(
                      onPressed: c.canReveal ? c.reveal : null,
                      child: Text(
                        text.continuationPageResumeTheSamePhotoRevealConsent,
                      ),
                    ),
                  ] else ...[
                    if (c.notice == 'reveal_withdrawn') ...[
                      Text(text.photoRevealWithdrawn),
                      const SizedBox(height: 14),
                    ],
                    HistaeButton.icon(
                      onPressed: c.canReveal ? onReveal : null,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(text.photoRevealShare),
                    ),
                  ],
                  if (!c.pendingWithdrawal &&
                      (c.myRevealed || c.pendingReveal)) ...[
                    const SizedBox(height: 12),
                    HistaeButton.textIcon(
                      onPressed: c.canWithdrawReveal ? onWithdraw : null,
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: Text(text.photoRevealWithdraw),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
