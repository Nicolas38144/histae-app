import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/subscription_plan.dart';
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
      unawaited(_catalog!.load());
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
      if (_catalog?.status == CatalogStatus.idle) unawaited(_catalog!.load());
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

  Future<void> _choose(SubscriptionPlan plan, BillingPeriod period) async {
    final strings = AppStrings.of(context);
    final price = period == BillingPeriod.monthly
        ? strings.monthly(plan.monthlyPriceCents, plan.currency)
        : strings.annual(plan.annualPriceCents, plan.currency);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poursuivre avec Premium'),
        content: SingleChildScrollView(
          child: Text(
            '$price\n\nAbonnement à renouvellement automatique. '
            'La date et le montant du premier paiement, ainsi que votre éventuel essai, seront confirmés avant validation dans le navigateur. '
            'Vous pourrez gérer la résiliation depuis votre abonnement. '
            'Les photos restent soumises à votre accord mutuel.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer dans le navigateur'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) await c.checkout(period);
  }

  Future<void> _refresh() async {
    if (!c.active) {
      await c.activate();
    } else {
      await c.load();
    }
  }

  @override
  Widget build(BuildContext context) => HistaeScaffold(
    appBar: AppBar(title: const Text('Mon abonnement')),
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
                  const EditorialCard(
                    eyebrow: 'À VOTRE RYTHME',
                    title: 'Plus de place\npour une histoire.',
                    body: 'Retrouvez votre formule et ce qu’elle vous permet de vivre. La révélation des photos demande toujours votre accord mutuel.',
                  ),
                  const SizedBox(height: 20),
                  if (!c.accessible)
                    const Text(
                      'Votre session doit être vérifiée pour consulter votre abonnement.',
                    )
                  else ...[
                    if (c.loading || !c.restored && c.failure == null)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Vérification de votre abonnement',
                      ),
                    if (c.subscription case final state?)
                      SubscriptionSummary(state: state),
                    if (!c.fresh && c.subscription != null)
                      const Text(
                        'Dernière situation connue. Actualisez pour confirmer vos droits actuels.',
                      ),
                    if (c.failure case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(BillingStrings.error(error)),
                      ),
                      if (error.requestId != null)
                        Text(
                          AppStrings.of(context)
                              .requestReference(error.requestId!),
                        ),
                    ],
                    if (BillingStrings.notice(c.notice).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(BillingStrings.notice(c.notice)),
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
                            : 'Vérifier mon abonnement',
                      ),
                    ),
                    if (c.busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Ouverture du navigateur',
                      ),
                    if (c.pending case final attempt?) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Une tentative ${attempt.period == BillingPeriod.monthly ? 'mensuelle' : 'annuelle'} est en attente de vérification. '
                        'Reprenez-la pour éviter une seconde souscription.',
                      ),
                      if (c.paymentsAvailable &&
                          c.subscription?.accessGranted != true)
                        OutlinedButton(
                          onPressed: _canAct
                              ? () => c.checkout(attempt.period)
                              : null,
                          child: const Text('Reprendre cette tentative'),
                        ),
                    ],
                    if (!c.paymentsAvailable) ...[
                      const EditorialDivider(),
                      const Text(
                        'La souscription et la gestion des paiements ne sont pas encore disponibles dans cette version. '
                        'Votre formule et vos droits existants restent consultables.',
                      ),
                    ],
                    if (c.subscription?.portalAvailable == true &&
                        c.paymentsAvailable)
                      OutlinedButton.icon(
                        onPressed: _canAct ? c.portal : null,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Gérer mon abonnement'),
                      ),
                  ],
                  const EditorialDivider(),
                  Text(
                    'Les formules',
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
