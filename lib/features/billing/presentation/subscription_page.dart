import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/read_snapshots.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/plan_catalog.dart';
import '../../notifications/application/push_controller.dart';
import '../../notifications/presentation/push_scope.dart';
import '../application/billing_controller.dart';
import '../data/billing_models.dart';
import 'billing_strings.dart';
import 'subscription_plans.dart';
import 'subscription_summary.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({
    super.key,
    required this.controller,
    this.catalog,
    this.notificationFlow = false,
  });
  final BillingController controller;
  final CatalogRepository? catalog;
  final bool notificationFlow;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with WidgetsBindingObserver {
  CatalogController? _catalog;
  PushController? _push;

  BillingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.catalog case final repository?) {
      _catalog = CatalogController(repository);
      unawaited(ReadSnapshots.forView(_catalog!.load));
    }
    unawaited(c.activate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PushScope.maybeOf(context);
    if (next != _push) {
      _push?.removeListener(_coverageChanged);
      _push = next;
      _push?.addListener(_coverageChanged);
    }
  }

  void _coverageChanged() {
    if (!widget.notificationFlow && _push?.coversMainFlow == true) {
      c.suspend();
    } else if (ModalRoute.of(context)?.isCurrent == true) {
      unawaited(c.activate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      c.suspend();
      _catalog?.suspend();
    } else if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(c.resume());
      if (_catalog?.status == CatalogStatus.idle) {
        unawaited(ReadSnapshots.forView(_catalog!.load));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _push?.removeListener(_coverageChanged);
    c.suspend();
    _catalog?.dispose();
    super.dispose();
  }

  Future<void> _choose(SubscriptionOffer offer) async {
    final period = offer.billingPeriod;
    if (period == null) return;
    final strings = AppStrings.of(context);
    final price = period == BillingPeriod.monthly
        ? strings.monthly(offer.priceCents, offer.currency)
        : strings.annual(offer.priceCents, offer.currency);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.of(context).messages
              .subscriptionPageContinueWith(offer.displayName),
        ),
        content: SingleChildScrollView(
          child: Text(
            AppStrings.of(context).messages
                .subscriptionPageAutoRenewingSubscriptionWithNoTrial(price),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.of(context).messages.notificationOverlayLater,
            ),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.of(context).messages.subscriptionPageContinueInBrowser,
            ),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) await c.checkout(period);
  }

  Future<void> _refresh() async {
    await c.activate();
    await c.load();
    await _catalog?.load();
  }

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    appBar: AppBar(
      title: Text(
        AppStrings.of(context).messages.accountBenefitsActionsMySubscription,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  EditorialCard(
                    eyebrow: AppStrings.of(context)
                        .messages
                        .subscriptionPageAtYourOwnPace,
                    title: AppStrings.of(context)
                        .messages
                        .subscriptionPageMoreRoomForAStory,
                    body: AppStrings.of(context)
                        .messages
                        .subscriptionPageFindYourPlanAndWhatIt,
                  ),
                  const SizedBox(height: 20),
                  if (!c.accessible)
                    Text(
                      AppStrings.of(context)
                          .messages
                          .subscriptionPageYourSessionMustBeVerifiedTo,
                    )
                  else ...[
                    if (c.loading || !c.restored && c.failure == null)
                      LinearProgressIndicator(
                        semanticsLabel: AppStrings.of(context)
                            .messages
                            .subscriptionPageCheckingYourSubscription,
                      ),
                    if (c.subscription case final state?)
                      SubscriptionSummary(state: state),
                    if (!c.fresh && c.subscription != null)
                      Text(
                        AppStrings.of(context)
                            .messages
                            .subscriptionPageLastKnownStatusRefreshToConfirm,
                      ),
                    if (c.failure case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          BillingStrings(AppStrings.of(context)).error(error),
                        ),
                      ),
                      if (error.requestId != null)
                        Text(
                          AppStrings.of(context)
                              .requestReference(error.requestId!),
                        ),
                    ],
                    if (BillingStrings(AppStrings.of(context))
                        .notice(c.notice)
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          BillingStrings(AppStrings.of(context))
                              .notice(c.notice),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: c.loading || c.busy || c.retrySeconds > 0
                          ? null
                          : _refresh,
                      child: Text(
                        c.retrySeconds > 0
                            ? AppStrings.of(context).retryIn(c.retrySeconds)
                            : AppStrings.of(context)
                                  .messages
                                  .subscriptionPageCheckMySubscription,
                      ),
                    ),
                    if (c.busy)
                      LinearProgressIndicator(
                        semanticsLabel: AppStrings.of(context)
                            .messages
                            .subscriptionPageOpeningBrowser,
                      ),
                    if (c.pending case final attempt?) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context).messages
                            .subscriptionPageAAttemptIsAwaitingVerificationResume(
                              attempt.period == BillingPeriod.monthly
                                  ? AppStrings.of(context)
                                        .messages
                                        .subscriptionPageMonthly
                                  : AppStrings.of(context)
                                        .messages
                                        .subscriptionPageAnnual,
                            ),
                      ),
                      if (c.paymentsAvailable &&
                          c.subscription?.accessGranted != true)
                        OutlinedButton(
                          onPressed: _canAct
                              ? () => c.checkout(attempt.period)
                              : null,
                          child: Text(
                            AppStrings.of(context)
                                .messages
                                .subscriptionPageResumeThisAttempt,
                          ),
                        ),
                    ],
                    if (!c.paymentsAvailable) ...[
                      const EditorialDivider(),
                      Text(
                        AppStrings.of(context)
                            .messages
                            .subscriptionPageSignUpAndPaymentManagementAre,
                      ),
                    ],
                    if (c.subscription?.portalAvailable == true &&
                        c.paymentsAvailable)
                      OutlinedButton.icon(
                        onPressed: _canAct ? c.portal : null,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          AppStrings.of(context)
                              .messages
                              .subscriptionPageManageMySubscription,
                        ),
                      ),
                  ],
                  const EditorialDivider(),
                  Text(
                    AppStrings.of(context).messages.subscriptionPagePlans,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_catalog case final catalog?)
                    ListenableBuilder(
                      listenable: catalog,
                      builder: (context, _) => SubscriptionPlans(
                        catalog: catalog,
                        paymentsAvailable: c.paymentsAvailable,
                        canSubscribe: c.subscription?.accessGranted == false,
                        hasPending: c.pending != null,
                        canAct: _canAct,
                        onChoose: _choose,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  bool get _canAct =>
      c.active && c.fresh && !c.busy && !c.loading && c.retrySeconds == 0;
}
