import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'biography_field.dart';
import 'birthdate_field.dart';
import 'profile_editor.dart';
import 'profile_identity_summary.dart';
import 'profile_strings.dart';

class IdentityEditor extends StatefulWidget {
  const IdentityEditor({super.key, required this.controller});
  final ProfileController controller;

  @override
  State<IdentityEditor> createState() => _IdentityEditorState();
}

class _IdentityEditorState extends ProfileEditorState<IdentityEditor> {
  @override
  ProfileController get controller => widget.controller;
  late final firstname = TextEditingController(
    text: controller.profile?.firstname,
  );
  late DateTime? birthdate = parseBirthdate(
    controller.profile?.birthdate ?? '',
  );
  late final bio = TextEditingController(text: controller.profile?.bio);
  late String sex = controller.profile?.sex ?? '';

  @override
  void dispose() {
    firstname.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final current = controller.profile;
    return page(
      text.discoveryStringsYourIntroduction,
      [
        EditorialCard(
          title: text.identityEditorYourOwnWay,
          body: text.identityEditorEverydayDetailsOftenMakeTheBest,
        ),
        const SizedBox(height: HistaeTokens.sectionSpacing),
        if (current == null)
          ..._creationFields(strings)
        else
          ProfileIdentitySummary(profile: current),
        const SizedBox(height: HistaeTokens.sectionSpacing),
        Padding(
          padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
          child: BiographyField(
            controller: bio,
            enabled: !busy && !controller.saving,
            onChanged: (_) => setState(changed),
          ),
        ),
      ],
      save: _save,
      saveEnabled: biographyByteLength(bio.text) <= biographyByteLimit,
    );
  }

  List<Widget> _creationFields(AppStrings strings) {
    final text = strings.messages;
    final editable = !busy && !controller.saving;
    return [
      field(firstname, text.identityEditorFirstName),
      Padding(
        padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
        child: BirthdateField(
          key: const Key('profile-birthdate'),
          value: birthdate,
          onChanged: editable
              ? (value) => setState(() {
                  birthdate = value;
                  changed();
                })
              : null,
        ),
      ),
      if (controller.sensitiveAllowed)
        DropdownButtonFormField<String>(
          initialValue: sex,
          isExpanded: true,
          decoration: InputDecoration(labelText: text.identityEditorSex),
          items: ProfileStrings(strings).sexes.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: editable
              ? (value) => setState(() {
                  sex = value!;
                  changed();
                })
              : null,
        )
      else
        Text(text.identityEditorSexIsOptionalWhenSavingThis),
    ];
  }

  Future<void> _save() async {
    final current = controller.profile;
    final biography = bio.text.isEmpty && current?.bio == null
        ? null
        : bio.text;
    final draft = current == null
        ? ProfileDraft(
            firstname.text,
            birthdate?.toIso8601String().substring(0, 10) ?? '',
            sex.isEmpty ? null : sex,
            biography,
          )
        : ProfileDraft.forBiography(current, biography);
    final error = draft.validate(DateTime.now());
    if (error != null) {
      setState(() => message = error);
      return;
    }
    await submit(() => controller.saveIdentity(draft));
  }
}
