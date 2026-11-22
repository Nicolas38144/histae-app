import '../../../core/l10n/generated/app_messages.dart';

String caseworkValueLabel(AppMessages messages, String? value) =>
    switch (value) {
      'login' => messages.caseworkLogin,
      'billing' => messages.caseworkBilling,
      'appeal' => messages.caseworkAppeal,
      'privacy' => messages.caseworkPrivacy,
      'pending' => messages.caseworkPending,
      'closed' => messages.caseworkClosed,
      'in_progress' => messages.caseworkInProgress,
      'completed' => messages.caseworkCompleted,
      'inappropriate_content' => messages.caseworkInappropriateContent,
      'fake_profile' => messages.caseworkFakeProfile,
      'harassment' => messages.caseworkHarassment,
      'spam' => messages.caseworkSpam,
      _ => messages.caseworkOther,
    };
