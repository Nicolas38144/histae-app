import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
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
      unawaited(_catalog!.ensureLoaded());
    }
    unawaited(c.activate(refresh: widget.notificationFlow));
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
        unawaited(_catalog!.ensureLoaded());
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
    final native = c.offers
        .where((item) => item.product.period == period)
        .firstOrNull;
    if (native == null) return;
    final price = period == BillingPeriod.monthly
        ? AppStrings.of(context).messages
              .billingStorePricePerMonth(native.price)
        : AppStrings.of(context).messages
              .billingStorePricePerYear(native.price);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.of(context).messages
              .subscriptionPageContinueWith(offer.displayName),
        ),
        content: SingleChildScrollView(
          child: Text(
            AppStrings.of(context).messages.billingStoreConfirm(price),
          ),
        ),
        actions: [
          HistaeButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.of(context).messages.notificationOverlayLater,
            ),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).messages.billingStoreContinue),
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
                  Text(
                    AppStrings.of(context)
                        .messages
                        .subscriptionPageFindYourPlanAndWhatIt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!c.accessible) ...[
                    Text(
                      AppStrings.of(context)
                          .messages
                          .subscriptionPageYourSessionMustBeVerifiedTo,
                    ),
                    _plans(context),
                  ] else ...[
                    if (c.loading)
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
                    _plans(context),
                    const SizedBox(height: 20),
                    HistaeButton.outlinedIcon(
                      onPressed: c.loading || c.busy || c.retrySeconds > 0
                          ? null
                          : _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
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
                            .billingStoreVerifying,
                      ),
                    if (c.purchasePending)
                      Text(AppStrings.of(context).messages.billingStorePending),
                    if (c.config.available) ...[
                      const SizedBox(height: 12),
                      HistaeButton.outlinedIcon(
                        onPressed: c.busy || c.loading
                            ? null
                            : c.restorePurchases,
                        icon: const Icon(Icons.restore_rounded, size: 20),
                        label: Text(
                          AppStrings.of(context)
                              .messages
                              .billingRestorePurchases,
                        ),
                      ),
                    ],
                    if (c.subscription?.provider == 'stripe')
                      Text(
                        AppStrings.of(context).messages.billingStoreManagedWeb,
                      ),
                    if (!c.paymentsAvailable) ...[
                      const EditorialDivider(),
                      Text(
                        AppStrings.of(context)
                            .messages
                            .subscriptionPageSignUpAndPaymentManagementAre,
                      ),
                    ],
                    if ([
                      'app_store',
                      'google_play',
                    ].contains(c.subscription?.provider))
                      HistaeButton.outlinedIcon(
                        onPressed: _canAct ? c.portal : null,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          AppStrings.of(context)
                              .messages
                              .subscriptionPageManageMySubscription,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _plans(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
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
            hasPending: c.purchasePending,
            storeOffers: c.offers,
            canAct: _canAct,
            onChoose: _choose,
          ),
        ),
    ],
  );

  bool get _canAct =>
      c.active && c.fresh && !c.busy && !c.loading && c.retrySeconds == 0;
}
