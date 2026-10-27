import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/weekly_renewal.dart';

class WeeklyRenewalLabel extends StatefulWidget {
  const WeeklyRenewalLabel({super.key});

  @override
  State<WeeklyRenewalLabel> createState() => _WeeklyRenewalLabelState();
}

class _WeeklyRenewalLabelState extends State<WeeklyRenewalLabel>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final local = nextWeeklyRenewal(DateTime.now()).toLocal();
    final formats = MaterialLocalizations.of(context);
    final date = formats.formatCompactDate(local);
    final time = formats.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Text(
      strings.messages.creditRenewalNext('$date $time'),
      key: const Key('weekly-renewal'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
