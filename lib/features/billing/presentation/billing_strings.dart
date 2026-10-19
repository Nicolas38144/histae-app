import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';

class BillingStrings {
  const BillingStrings(this.strings);
  final AppStrings strings;

  String date(DateTime value) => strings.date(value);

  String status(String? value) => switch (value) {
    'trialing' => strings.messages.billingStringsTrialPeriod,
    'active' => strings.messages.billingStringsActiveSubscription,
    'past_due' => strings.messages.billingStringsPaymentNeedsAttention,
    'incomplete' => strings.messages.billingStringsCompletePayment,
    'incomplete_expired' => strings.messages.billingStringsSubscriptionExpired,
    'canceled' => strings.messages.billingStringsSubscriptionCanceled,
    'unpaid' => strings.messages.billingStringsUnpaid,
    'paused' => strings.messages.billingStringsSubscriptionPaused,
    _ => strings.messages.billingStringsYourCurrentPlan,
  };

  String notice(String? value) => switch (value) {
    'confirmed' =>
      strings.messages.billingStringsYourEntitlementsHaveBeenConfirmedBy,
    'awaiting_confirmation' =>
      strings.messages.billingStringsPaymentOpenedInYourBrowserCheck,
    'portal_opened' =>
      strings.messages.billingStringsSubscriptionManagementOpenedInYourBrowser,
    'attempt_closed' =>
      strings.messages.billingStringsThePreviousAttemptHasEndedOr,
    _ => '',
  };

  String error(ApiFailure e) => switch (e.code) {
    'subscription_already_active' =>
      strings.messages.billingStringsASubscriptionAlreadyExistsRefreshYour,
    'checkout_already_in_progress' =>
      strings.messages.billingStringsASubscriptionAttemptIsAlreadyOpen,
    'billing_customer_reconciliation_required' ||
    'billing_customer_conflict' ||
    'checkout_state_conflict' =>
      strings.messages.billingStringsYourSubscriptionIsBeingCheckedTry,
    'idempotency_key_reused' =>
      strings.messages.billingStringsThisAttemptMustBeCheckedBefore,
    'idempotency_key_consumed' =>
      strings.messages.billingStringsThisAttemptHasEndedOrExpired,
    'billing_customer_not_found' =>
      strings.messages.billingStringsManagementOfThisSubscriptionIsNot,
    'browser_unavailable' =>
      strings.messages.billingStringsUnableToOpenTheBrowserYour,
    'billing_unavailable' ||
    'stripe_request_failed' ||
    'stripe_checkout_unavailable' =>
      strings.messages.billingStringsPaymentIsTemporarilyUnavailableYourAttempt,
    _ => switch (e.kind) {
      ApiFailureKind.network || ApiFailureKind.timeout =>
        strings.messages.billingStringsConnectionInterruptedTheResultStillNeeds,
      ApiFailureKind.rateLimited =>
        strings.messages.billingStringsPleaseWaitBeforeTryingAgain,
      ApiFailureKind.secureStorage =>
        strings.messages.billingStringsSecureStorageIsUnavailableNoNew,
      ApiFailureKind.invalidResponse =>
        strings.messages.billingStringsTheResponseDoesNotConfirmYour,
      _ => strings.messages.billingStringsYourSubscriptionCannotBeCheckedRight,
    },
  };
}
