import 'package:flutter/material.dart';

import '../widgets/histae_scaffold.dart';
import 'app_strings.dart';
import 'locale_controller.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => LocaleScope.maybeOf(context) == null
      ? const SizedBox.shrink()
      : IconButton(
          key: const Key('choose-language'),
          tooltip: AppStrings.of(context).messages.languageTitle,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const LanguagePage())),
          icon: const Icon(Icons.language),
        );
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.maybeOf(context)!;
    final copy = AppStrings.of(context).messages;
    final choices = <String?, String>{
      null: copy.languageSystem,
      'fr': copy.languageFrench,
      'en': copy.languageEnglish,
      'es': copy.languageSpanish,
      'it': copy.languageItalian,
    };
    return HistaeScaffold(
      appBar: AppBar(title: Text(copy.languageTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(copy.languageDescription),
            const SizedBox(height: 24),
            RadioGroup<String?>(
              groupValue: controller.language,
              onChanged: controller.saving ? (_) {} : controller.select,
              child: Column(
                children: [
                  for (final entry in choices.entries)
                    RadioListTile<String?>(
                      key: ValueKey('language-${entry.key ?? 'system'}'),
                      value: entry.key,
                      enabled: !controller.saving,
                      title: Text(entry.value),
                    ),
                ],
              ),
            ),
            if (controller.saving)
              LinearProgressIndicator(semanticsLabel: copy.languageSaving),
            if (controller.saveFailed)
              Semantics(
                liveRegion: true,
                child: Text(copy.languageSaveFailure),
              ),
          ],
        ),
      ),
    );
  }
}
