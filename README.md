# Histae mobile app

Flutter client for Histae: discover people through words, conversation and mutual photo reveal.
Android and iOS, French/English/Spanish/Italian, dark mode by default.

## Getting started

Use a Flutter SDK matching `pubspec.yaml` (Dart `^3.13.1`). Minimum platforms: Android API 24,
iOS 15. Native iOS builds require macOS and Xcode.

Complete the root `.env` with public settings only; it is bundled into the app:

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

Use the origin without `/api`; repositories supply the paths. Then run:

```bash
flutter pub get
flutter run
```

## Documentation

| Guide | Contents |
| --- | --- |
| [Configuration](docs/configuration.md) | Environment, support, ads, push and purchases |
| [Development](docs/development.md) | Conventions, focused checks and previews |
| [Architecture](ARCHITECTURE.md) | Ownership, cache, sessions and private data |
| [Design system](DESIGN_SYSTEM.md) | Branding and shared UI rules |
| [Product flows](resume.md) | User journeys and business behavior |
| [Roadmap](roadmap.md) | Remaining release validation |
| [Android release](docs/android-release.md) | Signing, recovery and Play bundles |
| [Store updates](docs/store-updates.md) | Update availability and blocking |
| [Session recovery](docs/session-recovery.md) | Refresh protocol and API rollout |
| [Localization](lib/core/l10n/README.md) / [API languages](docs/api-languages.md) | Interface and request languages |
| [Licensing](docs/licensing.md) | Dependency review and audit limits |

The Rust [HTTP contract](../histae-api-rust/docs/http-contract.md) defines routes, DTOs and
permissions; its [billing guide](../histae-api-rust/docs/store-billing.md) covers providers.

Run `flutter analyze` and existing tests relevant to the change; see [checks](docs/development.md#checks).
Documentation-only edits need no Flutter tests. Provider and native behavior require device validation.

## License

Copyright © 2026 Nicolas GERMANI. Original code is proprietary and available for inspection and
security audits only, under [LICENSE.md](LICENSE.md). Reuse requires prior written permission;
external contributions are not accepted. Dependencies retain their own licenses:
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
