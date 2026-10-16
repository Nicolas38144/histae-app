import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'profile_strings.dart';

Future<bool> confirmProfileAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmer',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

abstract class ProfileEditorState<T extends StatefulWidget> extends State<T> {
  ProfileController get controller;
  bool dirty = false, busy = false, leaving = false;
  String? message;
  late final String _resourceKey = controller.session.resourceKey;
  void changed() {
    dirty = true;
  }

  Future<void> submit(Future<void> Function() action) async {
    if (busy || !controller.canWrite) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await controller.mutate(action);
      if (mounted) {
        setState(() {
          dirty = false;
          leaving = true;
        });
        Navigator.pop(context);
      }
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

  Widget page(
    String title,
    List<Widget> children, {
    VoidCallback? save,
    String saveLabel = 'Enregistrer',
  }) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.accessible ||
          controller.session.resourceKey != _resourceKey) {
        return const Scaffold(body: SizedBox.shrink());
      }
      return PopScope(
        canPop: leaving || (!dirty && !busy),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || busy) return;
          if (await confirmProfileAction(
                context,
                'Quitter sans enregistrer ?',
                'Votre brouillon sera abandonné.',
                action: 'Quitter',
              ) &&
              mounted &&
              context.mounted) {
            setState(() {
              leaving = true;
            });
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...children,
                if (busy || controller.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Enregistrement ou relecture en cours',
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(message!)),
                  ),
                if (controller.uncertain)
                  const Text(
                    'Le résultat reste incertain. Relisez les données : aucune modification ne sera renvoyée automatiquement. Votre brouillon est conservé.',
                  ),
                if (message != null || controller.uncertain)
                  OutlinedButton(
                    onPressed:
                        busy ||
                            controller.loading ||
                            controller.retrySeconds > 0
                        ? null
                        : controller.load,
                    child: const Text('Relire les données serveur'),
                  ),
                const SizedBox(height: 24),
                if (save != null)
                  FilledButton(
                    onPressed: busy || !controller.canWrite ? null : save,
                    child: Text(
                      controller.retrySeconds > 0
                          ? 'Réessayez dans ${controller.retrySeconds} s'
                          : saveLabel,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget field(
    TextEditingController text,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: text,
      onChanged: (_) => setState(changed),
      enabled: !busy && !controller.saving,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 4,
      ),
      maxLines: lines,
      keyboardType: keyboard,
    ),
  );
}

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
      submit(() => controller.repository.saveProfile(draft));
    },
  );
}

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
      submit(() => controller.repository.savePreferences(p));
    },
  );
}

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
      await controller.mutate(
        () => controller.repository.setTrait(id, selected),
      );
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

class AnswersEditor extends StatefulWidget {
  const AnswersEditor({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<AnswersEditor> createState() => _AnswersEditorState();
}

class _AnswerInput {
  _AnswerInput(this.id, this.prompt, String value)
    : text = TextEditingController(text: value);
  final String id, prompt;
  final TextEditingController text;
}

class _AnswersEditorState extends ProfileEditorState<AnswersEditor> {
  @override
  ProfileController get controller => widget.controller;
  late final inputs = controller.answers
      .map((a) => _AnswerInput(a.questionId, a.question, a.answer))
      .toList();
  final removedInputs = <_AnswerInput>[];
  @override
  void dispose() {
    for (final a in [...inputs, ...removedInputs]) {
      a.text.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => page(
    'Vos réponses',
    [
      const EditorialCard(
        title: 'Une question.\nVotre regard.',
        body: 'Jusqu’à trois réponses, dans l’ordre qui vous ressemble. De 10 à 300 caractères chacune.',
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < inputs.length; i++)
        Card(
          key: ValueKey(inputs[i].id),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  inputs[i].prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                field(inputs[i].text, 'Réponse ${i + 1}', lines: 4),
                if (!controller.questions.any((q) => q.id == inputs[i].id))
                  const Text(
                    'Cette question n’est plus dans le catalogue. Retirez-la pour enregistrer une nouvelle sélection.',
                  ),
                for (final a in controller.answers.where(
                  (a) => a.questionId == inputs[i].id,
                ))
                  Text(ProfileStrings.moderation(a.moderation)),
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Monter la réponse ${i + 1}',
                      onPressed: i == 0 || busy
                          ? null
                          : () => setState(() {
                              final a = inputs.removeAt(i);
                              inputs.insert(i - 1, a);
                              changed();
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Descendre la réponse ${i + 1}',
                      onPressed: i == inputs.length - 1 || busy
                          ? null
                          : () => setState(() {
                              final a = inputs.removeAt(i);
                              inputs.insert(i + 1, a);
                              changed();
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              removedInputs.add(inputs.removeAt(i));
                              changed();
                            }),
                      child: const Text('Retirer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (inputs.length < 3) ...[
        const SizedBox(height: 24),
        Text(
          'Choisir une question',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (controller.questions.isEmpty)
          const Text('Aucune question n’est proposée pour le moment.'),
        for (final q in controller.questions.where(
          (q) => !inputs.any((a) => a.id == q.id),
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      inputs.add(_AnswerInput(q.id, q.prompt, ''));
                      changed();
                    }),
              child: Text(q.prompt),
            ),
          ),
      ],
    ],
    saveLabel: 'Enregistrer mes réponses',
    save: () async {
      final drafts = inputs.map((a) => AnswerDraft(a.id, a.text.text)).toList();
      for (final d in drafts) {
        final error = d.validate();
        if (error != null) {
          setState(() {
            message = error;
          });
          return;
        }
        if (!controller.questions.any((q) => q.id == d.questionId)) {
          setState(() {
            message = 'Retirez la question indisponible avant d’enregistrer.';
          });
          return;
        }
      }
      if (!await confirmProfileAction(
            context,
            inputs.isEmpty
                ? 'Effacer toutes vos réponses ?'
                : 'Enregistrer cette sélection ?',
            'Cette sélection remplacera toutes vos réponses actuelles, dans cet ordre.',
            action: inputs.isEmpty ? 'Tout effacer' : 'Enregistrer',
          ) ||
          !mounted) {
        return;
      }
      submit(() => controller.repository.saveAnswers(drafts));
    },
  );
}
