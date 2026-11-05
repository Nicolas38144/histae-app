import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/preference_field.dart';
import '../../../core/widgets/preference_slider.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'profile_editor.dart';
import 'profile_strings.dart';

class PreferencesEditor extends StatefulWidget {
  const PreferencesEditor({super.key, required this.controller});
  final ProfileController controller;

  @override
  State<PreferencesEditor> createState() => _PreferencesEditorState();
}

class _PreferencesEditorState extends ProfileEditorState<PreferencesEditor> {
  @override
  ProfileController get controller => widget.controller;
  late int min = controller.preferences?.minAge ?? 18;
  late int max = controller.preferences?.maxAge ?? 50;
  late int distance = controller.preferences?.distance ?? 50;
  late String? looking = controller.preferences?.lookingFor;

  bool get editable => !busy && !controller.saving;

  @override
  bool get hasUnsavedChanges {
    final saved = controller.preferences;
    if (saved == null) return dirty;
    return min != saved.minAge ||
        max != saved.maxAge ||
        distance != saved.distance ||
        looking != saved.lookingFor;
  }

  @override
  Widget build(BuildContext context) => page(
    AppStrings.of(context).messages.discoveryPageYourPreferences,
    [
      PreferenceField(
        label: AppStrings.of(context).messages.preferencesEditorIWantToMeet,
        child: Semantics(
          label: AppStrings.of(context).messages.preferencesEditorIWantToMeet,
          child: DropdownButtonFormField<String>(
            initialValue: looking,
            hint: Text(AppStrings.of(context).messages.preferencesChoose),
            isExpanded: true,
            isDense: false,
            itemHeight: null,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            items: ProfileStrings(AppStrings.of(context)).lookingFor.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: !editable
                ? null
                : (v) => setState(() {
                    looking = v;
                    changed();
                  }),
          ),
        ),
      ),
      PreferenceSlider(
        key: const Key('preferences-min-age'),
        label: AppStrings.of(context).messages.preferencesEditorMinimumAge,
        valueLabel: AppStrings.of(context).messages.registrationAgeValue(min),
        value: min,
        minimum: 18,
        maximum: max,
        onChanged: !editable
            ? null
            : (value) => setState(() {
                min = value;
                changed();
              }),
      ),
      PreferenceSlider(
        key: const Key('preferences-max-age'),
        label: AppStrings.of(context).messages.preferencesEditorMaximumAge,
        valueLabel: AppStrings.of(context).messages.registrationAgeValue(max),
        value: max,
        minimum: min,
        maximum: 99,
        onChanged: !editable
            ? null
            : (value) => setState(() {
                max = value;
                changed();
              }),
      ),
      PreferenceSlider(
        key: const Key('preferences-distance'),
        label: AppStrings.of(context)
            .messages
            .preferencesEditorMaximumDistanceKm,
        valueLabel: AppStrings.of(context).messages
            .registrationDistanceValue(distance),
        value: distance,
        minimum: 1,
        maximum: 500,
        onChanged: !editable
            ? null
            : (value) => setState(() {
                distance = value;
                changed();
              }),
      ),
    ],
    saveEnabled: controller.preferences == null || hasUnsavedChanges,
    saveInFooter: true,
    save: () {
      final p = Preferences(min, max, distance, looking ?? '');
      final error = p.validate();
      if (error != null) {
        setState(() {
          message = error;
        });
        return;
      }
      submit(() => controller.savePreferences(p));
    },
  );
}
