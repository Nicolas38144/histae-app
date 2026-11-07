# Interface localization

[Documentation](../../../README.md#documentation) · [API languages](../../../docs/api-languages.md)

The [ARB catalogues](arb/) contain all interface, validation and accessibility copy in French,
English, Spanish and Italian. Developer docs are English; unsupported app languages fall back to French.

## Editing messages

Add/update keys in all four catalogues, with placeholder metadata in the French template. Use ICU
plurals rather than sentence fragments. Remove unused keys from every locale, then regenerate:

```bash
flutter gen-l10n
```

Widgets use `AppStrings.of(context).messages`; `AppStrings` formats dates, numbers, prices and
errors. Other layers return codes/`ClientMessage`. Never hand-edit [generated Dart](generated/).
Device preference restores before first render; account fallback applies only without a local
choice. Language changes preserve navigation/drafts and never translate personal text.

## Native resources

After editing permission, privacy-shield copy or notification category names, regenerate and review
native iOS resources and Android notification-channel XML:

```bash
dart run tool/generate_native_localizations.dart
```

## Verification

`flutter test test/localization_test.dart` checks completeness, placeholders, plurals and label
conventions. Use `tool/preview_localizations_test.dart` for long translations, keyboard layouts and
200% text. See [Development](../../../docs/development.md#visual-previews) for preview commands.
