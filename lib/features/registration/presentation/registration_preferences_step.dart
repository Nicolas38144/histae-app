import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/presentation/profile_strings.dart';
import '../application/registration_draft.dart';

class RegistrationPreferencesStep extends StatefulWidget {
  const RegistrationPreferencesStep({
    super.key,
    required this.draft,
    required this.onContinue,
  });
  final RegistrationDraft draft;
  final VoidCallback onContinue;

  @override
  State<RegistrationPreferencesStep> createState() =>
      _RegistrationPreferencesStepState();
}

class _RegistrationPreferencesStepState
    extends State<RegistrationPreferencesStep> {
  late final _min = TextEditingController(
    text: widget.draft.preferences.minAge.toString(),
  );
  late final _max = TextEditingController(
    text: widget.draft.preferences.maxAge.toString(),
  );
  late final _distance = TextEditingController(
    text: widget.draft.preferences.distance.toString(),
  );
  late String? _looking = widget.draft.preferences.lookingFor.isEmpty
      ? null
      : widget.draft.preferences.lookingFor;
  ClientMessage? _error;

  void _changed() {
    widget.draft.preferences = Preferences(
      int.tryParse(_min.text) ?? -1,
      int.tryParse(_max.text) ?? -1,
      int.tryParse(_distance.text) ?? -1,
      _looking ?? '',
    );
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _distance.dispose();
    super.dispose();
  }

  Widget _number(TextEditingController controller, String label, String key) =>
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: TextField(
          key: Key(key),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => _changed(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final copy = strings.messages;
    return ListView(
      key: const PageStorageKey('registration-preferences'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(copy.preferencesEditorChooseYourFourPreferencesTheyWill),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          key: const Key('registration-looking-for'),
          initialValue: _looking,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: copy.preferencesEditorIWantToMeet,
          ),
          items: ProfileStrings(strings).lookingFor.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            _looking = value;
            _changed();
          },
        ),
        _number(_min, copy.preferencesEditorMinimumAge, 'registration-min-age'),
        _number(_max, copy.preferencesEditorMaximumAge, 'registration-max-age'),
        _number(
          _distance,
          copy.preferencesEditorMaximumDistanceKm,
          'registration-distance',
        ),
        const SizedBox(height: 20),
        Text(copy.registrationSensitiveDraft),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(strings.clientMessage(error)),
          ),
        ],
        const SizedBox(height: 24),
        HistaeButton(
          key: const Key('registration-next'),
          onPressed: () {
            _changed();
            final error = widget.draft.preferences.validate();
            if (error != null) {
              setState(() => _error = error);
              return;
            }
            FocusScope.of(context).unfocus();
            widget.onContinue();
          },
          child: Text(copy.registrationContinue),
        ),
      ],
    );
  }
}
