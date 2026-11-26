import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'histae_button.dart';

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String? action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          HistaeButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).messages.appStringsCancel),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action ??
                  AppStrings.of(context).messages.confirmationDialogConfirm,
            ),
          ),
        ],
      ),
    ) ??
    false;
