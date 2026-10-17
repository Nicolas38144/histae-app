import 'package:flutter/material.dart';

import 'histae_button.dart';

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmer',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

// Compatibility for clients importing the original profile editor barrel.
Future<bool> confirmProfileAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmer',
}) => confirmAction(context, title, message, action: action);
