# Development and verification

[Documentation](../README.md#documentation)

## Working conventions

Keep UI copy in the four ARB catalogues and business decisions in controllers/repositories.
Preserve dependency ownership and cancellation when changing a flow; see [Architecture](../ARCHITECTURE.md).
Use synthetic accounts and provider responses in tests and previews. Never log private data or
call administrator routes from the mobile app.

Do not run Git commands or recreate environment example files. Remove files only within an explicit
cleanup request, with evidence they are obsolete. Provide proposed commit messages in English.
Do not execute newly created or modified `.sh` scripts as part of local verification.

## Checks

Format the changed Dart files and analyze the project:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
```

Use tests for meaningful risks such as session isolation, sensitive data, uncertain writes and
payments. Run the relevant existing suite rather than testing every visual or documentation change.

| Change | Example focused command |
| --- | --- |
| Session/cache behavior | `flutter test test/read_snapshots_test.dart test/cache_lifecycle_regressions_test.dart` |
| Feed expiry, location or pause | `flutter test test/discovery_test.dart test/discovery_pause_test.dart` |
| Native billing | `flutter test test/billing_test.dart` |
| Interface/request language | `flutter test test/localization_test.dart test/api_language_test.dart` |

Tests use simulated providers. State exactly which checks ran and distinguish them from actual
device/provider validation. The current release backlog is in the [roadmap](../roadmap.md).

## Translations

After editing the catalogues:

```bash
flutter gen-l10n
```

Do not hand-edit generated Dart messages. When changing native permission copy, also follow the
[localization guide](../lib/core/l10n/README.md) to regenerate iOS resources.

## Visual previews

`tool/preview_*_test.dart` renders real widgets with synthetic content under `build/previews/`.
For example:

```bash
flutter test tool/preview_brand_test.dart --update-goldens
```

Some tools require `FLUTTER_ROOT` to point to the SDK to load platform fonts. Inspect the actual
images, long biographies and translations, 200% text, keyboard layouts and system insets.
Review the [design system](../DESIGN_SYSTEM.md) before changing shared components or brand assets.

For website screenshots, run `flutter test tool/preview_website_test.dart`, then the site's
`scripts/export-app-screenshots.mjs` converter. Keep profiles and conversations fictional and labelled.

## Builds and release preparation

```bash
flutter build apk --debug
```

This checks an Android development artifact, not store readiness. The checked-in Android release
build currently uses debug signing; configure production signing before distributing a release.
Keep signing credentials outside the public environment asset.

iOS builds require macOS, Xcode and the intended signing/provisioning setup. Validate native
permissions, Keychain, sharing, APNs, launch assets and store purchases on representative devices.
Do not infer iOS success from Android or widget tests.

Before beta, record the app/API versions, environment, tested flows and outstanding issues.
Provider enablement and local compilation are separate from approval and availability in the stores.
