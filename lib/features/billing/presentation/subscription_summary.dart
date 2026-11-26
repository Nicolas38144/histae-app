import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/billing_models.dart';
import 'billing_strings.dart';

class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({
    super.key,
    required this.state,
    required this.fresh,
  });
  final SubscriptionState state;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final billing = BillingStrings(strings);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final premium = state.accessGranted;
    final cadence = switch (state.billingPeriod) {
      BillingPeriod.monthly => text.subscriptionSummaryMonthlyPlan,
      BillingPeriod.annual => text.subscriptionSummaryAnnualPlan,
      null => null,
    };
    final dates = [
      if (state.periodStart case final start?)
        (
          label: text.subscriptionSummaryPeriodStartLabel,
          value: billing.date(start),
        ),
      if (state.periodEnd case final end?)
        (
          label: text.subscriptionSummaryPeriodEndLabel,
          value: billing.date(end),
        ),
    ];
    final notices = [
      if (state.cancelAtPeriodEnd)
        text.subscriptionSummaryCancellationScheduledForTheEndOf,
      if (state.canceledAt case final canceled?)
        text.subscriptionSummaryCancellationRecordedOn(billing.date(canceled)),
      if (state.status == 'past_due')
        text.subscriptionSummaryYourPaymentNeedsAttentionTheEntitlements,
    ];

    return Card(
      color: premium ? Colors.transparent : null,
      shape: premium
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HistaeTokens.panelRadius),
              side: BorderSide(color: colors.primary.withValues(alpha: 0.42)),
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: premium ? HistaeTokens.panelGradient(context) : null,
        ),
        child: Padding(
          padding: HistaeTokens.panelPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubscriptionHeading(premium: premium, cadence: cadence),
              if (premium || state.status != null || !fresh) ...[
                const SizedBox(height: HistaeTokens.contentSpacing),
                _SubscriptionStatus(state: state, fresh: fresh),
              ],
              if (dates.isNotEmpty) ...[
                const Divider(height: 28),
                _SubscriptionDates(dates: dates),
              ],
              for (final notice in notices) ...[
                const SizedBox(height: HistaeTokens.labelSpacing),
                Text(
                  notice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionHeading extends StatelessWidget {
  const _SubscriptionHeading({required this.premium, required this.cadence});
  final bool premium;
  final String? cadence;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = Text(
      text.billingStringsYourCurrentPlan,
      style: theme.textTheme.labelMedium?.copyWith(
        color: premium ? colors.primary : colors.onSurfaceVariant,
      ),
    );
    Widget heading(TextStyle? style) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            premium
                ? text.subscriptionSummaryHistaePremium
                : text.subscriptionSummaryHistaeFree,
            style: style,
          ),
        ),
        if (cadence case final interval?) ...[
          const SizedBox(height: 4),
          Text(
            interval,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: premium ? null : colors.primaryContainer,
        gradient: premium ? HistaeTokens.actionGradient : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        premium ? Icons.auto_awesome_rounded : Icons.menu_book_rounded,
        size: 22,
        color: premium ? HistaeTokens.night : colors.primary,
      ),
    );
    const gap = SizedBox(height: 6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < MediaQuery.textScalerOf(context).scale(196);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      if (!stacked) ...[
                        gap,
                        heading(theme.textTheme.headlineMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: HistaeTokens.labelSpacing),
                icon,
              ],
            ),
            if (stacked) ...[gap, heading(theme.textTheme.headlineSmall)],
          ],
        );
      },
    );
  }
}

class _SubscriptionStatus extends StatelessWidget {
  const _SubscriptionStatus({required this.state, required this.fresh});
  final SubscriptionState state;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final needsAttention =
        state.status == 'past_due' || state.status == 'on_hold';
    final description = !fresh
        ? text.subscriptionPageLastKnownStatusRefreshToConfirm
        : state.accessGranted
        ? text.subscriptionSummaryPremiumAccessConfirmedAtTheLast
        : null;
    final icon = switch (state.status) {
      _ when !fresh => Icons.history_rounded,
      'past_due' || 'on_hold' => Icons.error_outline_rounded,
      'active' ||
      null when state.accessGranted => Icons.check_circle_outline_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HistaeTokens.textSpacing,
        vertical: HistaeTokens.labelSpacing,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 17,
              color: needsAttention ? colors.error : colors.primary,
            ),
          ),
          const SizedBox(width: HistaeTokens.labelSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.status case final status?) ...[
                  Text(
                    BillingStrings(strings).status(status),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: needsAttention ? colors.error : colors.onSurface,
                    ),
                  ),
                  if (description != null) const SizedBox(height: 4),
                ],
                if (description != null)
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionDates extends StatelessWidget {
  const _SubscriptionDates({required this.dates});
  final List<({String label, String value})> dates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = HistaeTokens.contentSpacing;
        final available = constraints.maxWidth;
        final useColumns =
            dates.length == 2 &&
            available >= MediaQuery.textScalerOf(context).scale(248);
        final width = useColumns ? (available - gap) / 2 : available;
        return Wrap(
          spacing: gap,
          runSpacing: HistaeTokens.textSpacing,
          children: [
            for (final date in dates)
              SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: HistaeTokens.labelSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(date.value, style: theme.textTheme.labelLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
