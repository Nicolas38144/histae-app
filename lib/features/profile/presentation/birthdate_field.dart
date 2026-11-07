import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/profile_models.dart';

/// Calendar-only date selection shared by registration and profile editing.
class BirthdateField extends StatelessWidget {
  const BirthdateField({super.key, required this.value, this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;

  Future<void> _choose(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final first = DateTime(1900);
    final latest = latestAdultBirthdate(DateTime.now());
    final current = value;
    final initial = current == null
        ? latest
        : DateTime(current.year, current.month, current.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(latest)
          ? latest
          : initial,
      firstDate: first,
      lastDate: latest,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppStrings.of(context).messages.identityEditorDateOfBirth,
    );
    if (selected != null && context.mounted) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context).messages;
    return Semantics(
      button: true,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged == null ? null : () => _choose(context),
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            enabled: onChanged != null,
            labelText: copy.identityEditorDateOfBirth,
            helperText: copy.registrationAdultOnly,
            helperMaxLines: 4,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(
            value == null
                ? copy.registrationChooseDate
                : MaterialLocalizations.of(context).formatCompactDate(value!),
          ),
        ),
      ),
    );
  }
}
