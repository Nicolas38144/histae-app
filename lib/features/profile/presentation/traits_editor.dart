import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../application/profile_controller.dart';
import 'profile_editor.dart';
import 'profile_strings.dart';

class TraitsEditor extends StatefulWidget {
  const TraitsEditor({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<TraitsEditor> createState() => _TraitsEditorState();
}

class _TraitsEditorState extends ProfileEditorState<TraitsEditor> {
  @override
  ProfileController get controller => widget.controller;
  Future<void> toggle(String id, bool selected) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await controller.setTrait(id, selected);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          message = ProfileStrings.failure(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => page('Vos traits', [
    const Text(
      'Ce qui vous ressemble. Chaque choix est enregistré immédiatement.',
    ),
    const SizedBox(height: 24),
    if (controller.traits.isEmpty)
      const Text('Aucun trait n’est proposé pour le moment.'),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: controller.traits
          .map(
            (t) => FilterChip(
              label: Text(t.name),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              selected: controller.selectedTraits.any((s) => s.id == t.id),
              onSelected: busy || !controller.canWrite
                  ? null
                  : (v) => toggle(t.id, v),
            ),
          )
          .toList(),
    ),
  ]);
}
