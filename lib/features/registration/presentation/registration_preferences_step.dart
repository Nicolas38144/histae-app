import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/presentation/profile_strings.dart';
import '../application/registration_draft.dart';
import 'preference_slider.dart';

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
  late int _min = widget.draft.preferences.minAge;
  late int _max = widget.draft.preferences.maxAge;
  late int _distance = widget.draft.preferences.distance;
  late String? _looking = widget.draft.preferences.lookingFor.isEmpty
      ? null
      : widget.draft.preferences.lookingFor;
  ClientMessage? _error;

  void _changed() {
    widget.draft.preferences = Preferences(
      _min,
      _max,
      _distance,
      _looking ?? '',
    );
    if (_error != null) setState(() => _error = null);
  }

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
        PreferenceSlider(
          key: const Key('registration-min-age'),
          label: copy.preferencesEditorMinimumAge,
          valueLabel: copy.registrationAgeValue(_min),
          value: _min,
          minimum: 18,
          maximum: _max,
          onChanged: (value) => setState(() {
            _min = value;
            _changed();
          }),
        ),
        PreferenceSlider(
          key: const Key('registration-max-age'),
          label: copy.preferencesEditorMaximumAge,
          valueLabel: copy.registrationAgeValue(_max),
          value: _max,
          minimum: _min,
          maximum: 99,
          onChanged: (value) => setState(() {
            _max = value;
            _changed();
          }),
        ),
        PreferenceSlider(
          key: const Key('registration-distance'),
          label: copy.preferencesEditorMaximumDistanceKm,
          valueLabel: copy.registrationDistanceValue(_distance),
          value: _distance,
          minimum: 1,
          maximum: 500,
          onChanged: (value) => setState(() {
            _distance = value;
            _changed();
          }),
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
