import 'package:flutter/material.dart';

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
    'Votre présentation',
    [
      const EditorialCard(
        title: 'À votre façon.',
        body: 'Les détails du quotidien font souvent les plus belles conversations.',
      ),
      const SizedBox(height: 24),
      field(firstname, 'Prénom'),
      field(
        birthdate,
        'Date de naissance',
        keyboard: TextInputType.datetime,
        hint: 'AAAA-MM-JJ · Vous devez avoir 18 ans ou plus.',
      ),
      if (controller.sensitiveAllowed)
        DropdownButtonFormField<String>(
          initialValue: sex,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sexe'),
          items: ProfileStrings.sexes.entries
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
        const Text(
          'Le sexe est facultatif pour enregistrer ce profil. Son utilisation demande votre consentement aux données sensibles, accessible depuis vos choix de vie privée.',
        ),
      const SizedBox(height: 24),
      field(
        bio,
        'Quelques mots sur vous',
        lines: 5,
        hint: '2 000 octets maximum · Évitez vos coordonnées.',
      ),
      if (controller.profile?.bioModeration != null)
        Text(ProfileStrings.moderation(controller.profile!.bioModeration)),
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
