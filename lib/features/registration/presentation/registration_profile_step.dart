import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/presentation/biography_field.dart';
import '../../profile/presentation/birthdate_field.dart';
import '../../profile/presentation/profile_strings.dart';
import '../application/registration_draft.dart';

class RegistrationProfileStep extends StatefulWidget {
  const RegistrationProfileStep({
    super.key,
    required this.draft,
    required this.onContinue,
  });
  final RegistrationDraft draft;
  final VoidCallback onContinue;

  @override
  State<RegistrationProfileStep> createState() =>
      _RegistrationProfileStepState();
}

class _RegistrationProfileStepState extends State<RegistrationProfileStep> {
  late final _firstname = TextEditingController(
    text: widget.draft.profile.firstname,
  );
  late DateTime? _birthdate = parseBirthdate(widget.draft.profile.birthdate);
  late final _bio = TextEditingController(text: widget.draft.profile.bio);
  late String _sex = widget.draft.profile.sex ?? 'male';
  ClientMessage? _error;

  void _changed() {
    widget.draft.profile = ProfileDraft(
      _firstname.text,
      _birthdate?.toIso8601String().substring(0, 10) ?? '',
      _sex,
      _bio.text.trim().isEmpty ? null : _bio.text,
    );
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _firstname.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final copy = strings.messages;
    return ListView(
      key: const PageStorageKey('registration-profile'),
      padding: HistaeTokens.pagePadding,
      children: [
        EditorialCard(
          title: copy.identityEditorYourOwnWay,
          body: copy.identityEditorEverydayDetailsOftenMakeTheBest,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('registration-firstname'),
          controller: _firstname,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          decoration: InputDecoration(labelText: copy.identityEditorFirstName),
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 20),
        BirthdateField(
          key: const Key('registration-birthdate'),
          value: _birthdate,
          onChanged: (value) => setState(() {
            _birthdate = value;
            _changed();
          }),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          key: const Key('registration-sex'),
          initialValue: _sex,
          isExpanded: true,
          decoration: InputDecoration(labelText: copy.identityEditorSex),
          items: ProfileStrings(strings).sexes.entries
              .where((entry) => entry.key.isNotEmpty)
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            _sex = value ?? 'male';
            _changed();
          },
        ),
        const SizedBox(height: 20),
        BiographyField(
          key: const Key('registration-bio'),
          controller: _bio,
          minLines: MediaQuery.textScalerOf(context).scale(16) > 20 ? 3 : 6,
          maxLines: 12,
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 20),
        Text(copy.registrationLocalDraft),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(strings.clientMessage(error)),
          ),
        ],
        const SizedBox(height: 24),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _bio,
          builder: (context, value, _) => HistaeButton(
            key: const Key('registration-next'),
            onPressed: biographyByteLength(value.text) <= biographyByteLimit
                ? _continue
                : null,
            child: Text(copy.registrationContinue),
          ),
        ),
      ],
    );
  }

  void _continue() {
    _changed();
    final error = widget.draft.profile.validate(DateTime.now());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onContinue();
  }
}
