import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
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
  late final min = TextEditingController(
    text: controller.preferences?.minAge.toString(),
  );
  late final max = TextEditingController(
    text: controller.preferences?.maxAge.toString(),
  );
  late final distance = TextEditingController(
    text: controller.preferences?.distance.toString(),
  );
  late String? looking = controller.preferences?.lookingFor;

  @override
  void dispose() {
    min.dispose();
    max.dispose();
    distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => page(
    AppStrings.of(context).messages.discoveryPageYourPreferences,
    [
      Text(
        AppStrings.of(context)
            .messages
            .preferencesEditorChooseYourFourPreferencesTheyWill,
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: looking,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: AppStrings.of(context)
              .messages
              .preferencesEditorIWantToMeet,
        ),
        items: ProfileStrings(AppStrings.of(context)).lookingFor.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: busy
            ? null
            : (v) => setState(() {
                looking = v;
                changed();
              }),
      ),
      const SizedBox(height: 24),
      field(
        min,
        AppStrings.of(context).messages.preferencesEditorMinimumAge,
        keyboard: TextInputType.number,
      ),
      field(
        max,
        AppStrings.of(context).messages.preferencesEditorMaximumAge,
        keyboard: TextInputType.number,
      ),
      field(
        distance,
        AppStrings.of(context).messages.preferencesEditorMaximumDistanceKm,
        keyboard: TextInputType.number,
      ),
    ],
    save: () {
      final p = Preferences(
        int.tryParse(min.text) ?? -1,
        int.tryParse(max.text) ?? -1,
        int.tryParse(distance.text) ?? -1,
        looking ?? '',
      );
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
