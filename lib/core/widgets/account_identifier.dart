import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

/// Private account details only. Never include this in public profile previews.
class AccountIdentifier extends StatelessWidget {
  const AccountIdentifier({super.key, required this.userId});
  final String userId;

  Future<void> _copy(BuildContext context) async {
    final messages = AppStrings.of(context).messages;
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: userId));
      message = messages.accountIdentifierCopied;
    } on PlatformException {
      message = messages.accountIdentifierCopyFailed;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = AppStrings.of(context).messages;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messages.accountIdentifierTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectionArea(
                child: Text(
                  userId,
                  key: const Key('account-user-id'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: messages.accountIdentifierCopy,
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    );
  }
}
