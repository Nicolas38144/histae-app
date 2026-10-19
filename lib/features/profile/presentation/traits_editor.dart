import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../application/profile_controller.dart';
import 'profile_editor.dart';

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
      messageFailure = null;
    });
    try {
      await controller.setTrait(id, selected);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          messageFailure = e;
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
  Widget build(BuildContext context) =>
      page(AppStrings.of(context).messages.traitsEditorYourTraits, [
        Text(
          AppStrings.of(context).messages.traitsEditorWhatMakesYouYouEachChoice,
        ),
        const SizedBox(height: 24),
        if (controller.traits.isEmpty)
          Text(
            AppStrings.of(context)
                .messages
                .traitsEditorNoTraitsAreCurrentlyAvailable,
          ),
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
