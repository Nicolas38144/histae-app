import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/read_snapshots.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/notification_setting_controller.dart';

/// The route owns cancellation; repositories keep session-scoped read snapshots.
class NotificationSettingView<T> extends StatefulWidget {
  const NotificationSettingView({
    super.key,
    required this.create,
    required this.builder,
  });
  final NotificationSettingController<T> Function() create;
  final Widget Function(BuildContext, NotificationSettingController<T>) builder;

  @override
  State<NotificationSettingView<T>> createState() =>
      _NotificationSettingViewState<T>();
}

class _NotificationSettingViewState<T> extends State<NotificationSettingView<T>>
    with WidgetsBindingObserver {
  late final c = widget.create();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Opening an editor needs current server choices, including another device's
    // edits. This does not fetch anything while switching the app's main tabs.
    unawaited(c.load(policy: ReadPolicy.refresh));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(c.resume());
    } else {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) =>
        c.accessible ? widget.builder(context, c) : const SizedBox.shrink(),
  );
}

class NotificationSettingStatus<T> extends StatelessWidget {
  const NotificationSettingStatus({super.key, required this.controller});
  final NotificationSettingController<T> controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final text = AppStrings.of(context).messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(
              semanticsLabel: text.notificationSettingsLoading,
            ),
          ),
        if (c.failure != null) ...[
          const SizedBox(height: 12),
          Text(
            c.failure!.kind == ApiFailureKind.notFound
                ? text.notificationSettingsUnavailable
                : text.notificationSettingsUnconfirmed,
          ),
          const SizedBox(height: 12),
          HistaeButton.outlined(
            onPressed: c.active && !c.busy && c.retrySeconds == 0
                ? () => unawaited(c.load(policy: ReadPolicy.refresh))
                : null,
            child: Text(
              c.retrySeconds > 0
                  ? text.appStringsTryAgainInS(c.retrySeconds)
                  : text.notificationSettingsRetry,
            ),
          ),
        ],
      ],
    );
  }
}
