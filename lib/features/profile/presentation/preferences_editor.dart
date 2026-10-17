import 'package:flutter/material.dart';

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
    'Vos préférences',
    [
      const Text(
        'Choisissez vos quatre préférences. Elles seront enregistrées ensemble.',
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: looking,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Je souhaite rencontrer'),
        items: ProfileStrings.lookingFor.entries
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
      field(min, 'Âge minimum', keyboard: TextInputType.number),
      field(max, 'Âge maximum', keyboard: TextInputType.number),
      field(distance, 'Distance maximale (km)', keyboard: TextInputType.number),
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
