import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../matches/data/match_models.dart';
import '../../matches/presentation/matches_strings.dart';
import '../application/continuation_controller.dart';
import 'continuation_strings.dart';
import 'continuation_subscription_navigation.dart';
import 'credit_recovery_card.dart';
import 'credits_page.dart';
import 'partner_photo_page.dart';
import 'photo_reveal_panel.dart';

class ContinuationPage extends StatefulWidget {
  const ContinuationPage({
    super.key,
    required this.controller,
    required this.matchId,
    this.catalog,
  });
  final ContinuationController controller;
  final String matchId;
  final CatalogRepository? catalog;

  @override
  State<ContinuationPage> createState() => _ContinuationPageState();
}

class _ContinuationPageState extends State<ContinuationPage>
    with WidgetsBindingObserver {
  ContinuationController get c => widget.controller;
  late final _key = c.access.session.resourceKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    if (mounted && c.access.session.resourceKey == _key) await c.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.suspend(notify: false);
    super.dispose();
  }

  Future<void> _continue() async {
    final offer = await c.prepareContinuation();
    if (!mounted) return;
    if (offer == null) {
      final quota = c.quota;
      if (c.quotaReadAt != null && c.canContinue && c.pendingCost == null) {
        if (quota?.weeklyLimitReached == true) {
          await _openSubscription();
        } else if (quota?.suggestsRewardedVideo == true && !quota!.canStart) {
          await _openCredits(focusVideo: true);
        }
      }
      return;
    }
    final accepted = await confirmAction(
      context,
      AppStrings.of(context).messages.continuationPageContinueThisMatch,
      offer.cost == 0
          ? AppStrings.of(context)
                .messages
                .continuationPageYourCurrentPlanRequiresNoCredit
          : AppStrings.of(context)
                .messages
                .continuationPageYouAcceptAMaximumCostOf,
      action: offer.cost == 0
          ? AppStrings.of(context)
                .messages
                .continuationPageContinueWithoutCredits
          : AppStrings.of(context).messages.continuationPageAcceptUpTo1Credit,
    );
    if (accepted && mounted) await c.accept(offer);
  }

  Future<void> _openCredits({bool focusVideo = false}) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => CreditsPage(
        controller: c,
        catalog: widget.catalog,
        focusVideo: focusVideo,
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    if (mounted) await c.activate();
  }

  Future<void> _openSubscription() => openContinuationSubscription(
    context,
    credits: c,
    catalog: widget.catalog,
  );

  Future<void> _reveal() async {
    if (await confirmAction(
          context,
          AppStrings.of(context).messages.continuationPageRevealYourPhotos,
          AppStrings.of(context)
              .messages
              .continuationPageYourPhotoMayBecomeVisibleIn,
          action: AppStrings.of(context).messages.continuationPageGiveMyConsent,
        ) &&
        mounted) {
      await c.reveal();
    }
  }

  Future<void> _withdrawReveal() async {
    final text = AppStrings.of(context).messages;
    if (await confirmAction(
          context,
          text.photoRevealWithdrawTitle,
          text.photoRevealWithdrawBody,
          action: text.photoRevealWithdraw,
        ) &&
        mounted) {
      await c.withdrawReveal();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.access]),
    builder: (context, _) {
      final m = c.match?.id == widget.matchId ? c.match : null;
      final allowed =
          c.accessible &&
          c.access.session.resourceKey == _key &&
          m?.historyAllowed == true;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.of(context).messages.continuationPageYourMatch,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!allowed)
                EditorialCard(
                  title: AppStrings.of(context)
                      .messages
                      .continuationPageThisMatchIsNoLongerAvailable,
                  body: AppStrings.of(context)
                      .messages
                      .continuationPageReturnToYourMatchesToCheck,
                )
              else ...[
                EditorialCard(
                  eyebrow: m!.partner.firstname.toUpperCase(),
                  title: AppStrings.of(context)
                      .messages
                      .continuationPageTheNextChapterIsWrittenTogether,
                  body: m.status == MatchStatus.active
                      ? null
                      : MatchesStrings(AppStrings.of(context)).stateBody(m),
                ),
                if (c.loading || c.busy || !c.access.verified)
                  LinearProgressIndicator(
                    semanticsLabel: AppStrings.of(context)
                        .messages
                        .continuationPageRefreshingMatch,
                  ),
                if (c.failure case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      ContinuationStrings(AppStrings.of(context))
                          .failure(error),
                    ),
                  ),
                if (c.notice == 'cost_changed')
                  Text(
                    AppStrings.of(context)
                        .messages
                        .continuationPageTheCostMustBeCheckedAnd,
                  ),
                const SizedBox(height: 20),
                PhotoRevealPanel(
                  controller: c,
                  onReveal: _reveal,
                  onWithdraw: _withdrawReveal,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PartnerPhotoPage(access: c.access, matchId: m.id),
                    ),
                  ),
                ),
                const EditorialDivider(),
                Text(
                  AppStrings.of(context)
                      .messages
                      .continuationPageContinueThisConversation,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (m.status == MatchStatus.confirmed)
                  Text(
                    AppStrings.of(context)
                        .messages
                        .continuationPageYourConversationIsOpenContinuationConditions,
                  ),
                if (m.status == MatchStatus.awaitingContinuation) ...[
                  Text(
                    AppStrings.of(context).messages
                        .continuationPageYouCanDecideUntilYouCan(
                          MatchesStrings(AppStrings.of(context))
                              .date(m.expiresAt),
                        ),
                  ),
                  if (c.myContinued)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .continuationPageYourChoiceToContinueHasBeen,
                      ),
                    )
                  else if (c.pendingCost case final cost?) ...[
                    Text(
                      AppStrings.of(context).messages
                          .continuationPageThisRequestStillNeedsConfirmationWith(
                            cost,
                          ),
                    ),
                    HistaeButton(
                      onPressed: c.canContinue ? c.resumeContinuation : null,
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .continuationPageResumeTheSameAgreement,
                      ),
                    ),
                  ] else ...[
                    if (c.quotaReadAt != null && c.quota != null)
                      Text(
                        c.quota!.premium
                            ? AppStrings.of(context)
                                  .messages
                                  .continuationPageYourCurrentPlanNoCreditNeeded
                            : AppStrings.of(context).messages
                                  .continuationsAndCost(c.quota!.remaining!),
                      ),
                    HistaeButton(
                      onPressed:
                          c.canContinue &&
                              c.quota?.canStart == true &&
                              c.quotaReadAt != null
                          ? _continue
                          : null,
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .continuationPageReadTheCostAndChooseTo,
                      ),
                    ),
                    if (c.quotaReadAt != null &&
                        c.quota != null &&
                        (c.quota!.weeklyLimitReached ||
                            c.quota!.suggestsRewardedVideo)) ...[
                      const SizedBox(height: 16),
                      CreditRecoveryCard(
                        quota: c.quota!,
                        enabled: c.canContinue,
                        onWatchVideo: () => _openCredits(focusVideo: true),
                        onOpenSubscription: _openSubscription,
                      ),
                    ] else if (c.quotaReadAt != null &&
                        c.quota?.canStart == false)
                      Text(
                        AppStrings.of(context)
                            .messages
                            .continuationPageYourAllowanceDoesNotPermitAnother,
                      ),
                  ],
                ],
                HistaeButton.text(
                  onPressed: c.busy ? null : _openCredits,
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .continuationPageViewMyCredits,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context)
                      .messages
                      .continuationPageEachPersonChoosesIndependentlyTheOther,
                ),
                if (c.retrySeconds > 0)
                  Text(
                    AppStrings.of(context).messages
                        .appStringsTryAgainInS(c.retrySeconds),
                  ),
                HistaeButton.outlinedIcon(
                  onPressed: c.busy || c.loading || c.retrySeconds > 0
                      ? null
                      : () async {
                          await c.access.refresh();
                          await c.activate();
                          await c.loadQuota();
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    AppStrings.of(context)
                        .messages
                        .continuationPageRefreshMatchAndMyCredits,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
