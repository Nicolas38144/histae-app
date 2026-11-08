import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'birthdate_field.dart';
import 'profile_editor.dart';
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
  Widget build(BuildContext context) => page(
    AppStrings.of(context).messages.discoveryStringsYourIntroduction,
    [
      EditorialCard(
        title: AppStrings.of(context).messages.identityEditorYourOwnWay,
        body: AppStrings.of(context)
            .messages
            .identityEditorEverydayDetailsOftenMakeTheBest,
      ),
      const SizedBox(height: 24),
      if (controller.profile case final current?)
        _lockedField(
          AppStrings.of(context).messages.identityEditorFirstName,
          current.firstname,
        )
      else
        field(
          firstname,
          AppStrings.of(context).messages.identityEditorFirstName,
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
        child: BirthdateField(
          key: const Key('profile-birthdate'),
          value: controller.profile == null
              ? birthdate
              : parseBirthdate(controller.profile!.birthdate),
          onChanged: controller.profile != null || busy || controller.saving
              ? null
              : (value) => setState(() {
                  birthdate = value;
                  changed();
                }),
        ),
      ),
      if (controller.profile case final current?)
        _lockedField(
          AppStrings.of(context).messages.identityEditorSex,
          ProfileStrings(AppStrings.of(context)).sexes[current.sex ?? '']!,
        )
      else if (controller.sensitiveAllowed)
        DropdownButtonFormField<String>(
          initialValue: sex,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).messages.identityEditorSex,
          ),
          items: ProfileStrings(AppStrings.of(context)).sexes.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: busy
              ? null
              : (v) => setState(() {
                  sex = v!;
                  changed();
                }),
        ),
      if (controller.profile == null && !controller.sensitiveAllowed)
        Text(
          AppStrings.of(context)
              .messages
              .identityEditorSexIsOptionalWhenSavingThis,
        ),
      if (controller.profile != null)
        Text(
          AppStrings.of(context).messages.profileIdentityLocked,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: HistaeTokens.sectionSpacing),
      field(
        bio,
        AppStrings.of(context).messages.identityEditorAFewWordsAboutYou,
        lines: 5,
        hint: AppStrings.of(context)
            .messages
            .identityEditor2000BytesMaximumAvoidContact,
      ),
    ],
    save: () {
      final current = controller.profile;
      final draft = ProfileDraft(
        current?.firstname ?? firstname.text,
        current?.birthdate ??
            birthdate?.toIso8601String().substring(0, 10) ??
            '',
        current != null
            ? current.sex
            : sex.isEmpty
            ? null
            : sex,
        bio.text.isEmpty && controller.profile?.bio == null ? null : bio.text,
      );
      final error = draft.validate(DateTime.now());
      if (error != null) {
        setState(() {
          message = error;
        });
        return;
      }
      submit(() => controller.saveIdentity(draft));
    },
  );

  Widget _lockedField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: false),
      child: Text(value),
    ),
  );
}
