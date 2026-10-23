# Interface localization

[Documentation](../../../README.md#documentation) · [API languages](../../../docs/api-languages.md)

The four [ARB catalogues](arb/) contain French, English, Spanish and Italian interface text,
validation, confirmations and accessibility labels. Developer documentation is written in English;
this does not change the app's supported languages or French fallback.

## Add or update a message

1. Add a descriptive key to all four catalogues, with placeholder metadata in the French template.
2. Use ICU plurals rather than concatenating sentence fragments or suffixes.
3. Run generation from the app root:

```bash
flutter gen-l10n
```

Use `AppStrings.of(context).messages` for copy and `AppStrings` for date, number, price and error
formatting. Data/application layers return codes or `ClientMessage`; presentation translates them.
Do not edit [generated Dart files](generated/) by hand. Remove genuinely unused keys from every
locale and regenerate rather than keeping obsolete copy indefinitely.

## Language preference and content

`LocaleController` restores the device preference before the first render. Without an explicit
local choice, `AccountLanguageBinding` can adopt the verified account's language. System mode
resolves the device's primary language; unsupported languages use French.

Changing language retains navigation and drafts. The API localizes catalogues and documents using
`Accept-Language`, but personal text is not translated. Document presentation/acceptance language
is separate from interface preference. Native and provider dialogs use their own settings.

## Native permission resources

After changing the relevant iOS permission messages, also regenerate native localizations:

```bash
dart run tool/generate_native_localizations.dart
```

Review the generated native resources; Dart localization alone does not update every system dialog.

## Focused verification

```bash
flutter test test/localization_test.dart
```

The suite checks catalogue completeness, placeholders, plurals and hardcoded-label conventions.
For visual review, use `tool/preview_localizations_test.dart`, including long translations, 200% text
and keyboard layouts. See [Development](../../../docs/development.md) for shared checks and previews.
