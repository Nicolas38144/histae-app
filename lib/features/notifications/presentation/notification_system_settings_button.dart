import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/notification_system_settings.dart';

class NotificationSystemSettingsButton extends StatefulWidget {
  const NotificationSystemSettingsButton({super.key});
  @override
  State<NotificationSystemSettingsButton> createState() =>
      _NotificationSystemSettingsButtonState();
}

class _NotificationSystemSettingsButtonState
    extends State<NotificationSystemSettingsButton> {
  bool _busy = false, _failed = false;
  Future<void> _open() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final opened = await openNotificationSystemSettings();
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.notificationSystemSettingsDescription),
        const SizedBox(height: 8),
        HistaeButton.textIcon(
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.settings_outlined),
          label: Text(text.notificationSystemSettings),
        ),
        if (_failed) Text(text.notificationSystemSettingsFailed),
      ],
    );
  }
}
