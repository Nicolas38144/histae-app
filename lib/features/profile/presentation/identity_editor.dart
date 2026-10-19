import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
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
  late final birthdate = TextEditingController(
    text: controller.profile?.birthdate,
  );
  late final bio = TextEditingController(text: controller.profile?.bio);
  late String sex = controller.profile?.sex ?? '';

  @override
  void dispose() {
    firstname.dispose();
    birthdate.dispose();
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
      field(firstname, AppStrings.of(context).messages.identityEditorFirstName),
      field(
        birthdate,
        AppStrings.of(context).messages.identityEditorDateOfBirth,
        keyboard: TextInputType.datetime,
        hint: AppStrings.of(context).messages.identityEditorYyyyMmDdYouMustBe,
      ),
      if (controller.sensitiveAllowed)
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
      if (!controller.sensitiveAllowed)
        Text(
          AppStrings.of(context)
              .messages
              .identityEditorSexIsOptionalWhenSavingThis,
        ),
      const SizedBox(height: 24),
      field(
        bio,
        AppStrings.of(context).messages.identityEditorAFewWordsAboutYou,
        lines: 5,
        hint: AppStrings.of(context)
            .messages
            .identityEditor2000BytesMaximumAvoidContact,
      ),
      if (controller.profile?.bioModeration != null)
        Text(
          ProfileStrings(AppStrings.of(context))
              .moderation(controller.profile!.bioModeration),
        ),
    ],
    save: () {
      final draft = ProfileDraft(
        firstname.text,
        birthdate.text.trim(),
        sex.isEmpty ? null : sex,
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
}
