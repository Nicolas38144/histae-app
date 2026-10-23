# Histae mobile app

Histae is a dating app that gives people room to discover each other through words, conversation
and mutual photo reveal. This Flutter client targets Android and iOS, supports French, English,
Spanish and Italian, and starts in dark mode.

## Getting started

Use a Flutter SDK compatible with the Dart constraint in `pubspec.yaml` (`^3.13.1`). Android requires
API 24 or later; iOS targets version 15 or later and requires macOS and Xcode for native builds.

Create or complete the root `.env` with public client configuration:

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

Use the origin only, without `/api`: repositories append `/api/...` themselves.
The `.env` is bundled into the app, so it must contain no server secrets.
See [Configuration](docs/configuration.md) for local development and optional providers.

```bash
flutter pub get
flutter run
```

## Documentation

| Guide | Purpose |
| --- | --- |
| [Configuration](docs/configuration.md) | Public environment, AdMob, Firebase and native purchases |
| [Development](docs/development.md) | Checks, previews, build preparation and working conventions |
| [Architecture](ARCHITECTURE.md) | Ownership, layers, cache, sessions and native adapters |
| [Design system](DESIGN_SYSTEM.md) | Voice, branding, typography and UI behavior |
| [Product flows](resume.md) | Account, profile, feed, matches, credits and privacy |
| [Roadmap](roadmap.md) | Remaining device, provider and release validation |
| [Localization](lib/core/l10n/README.md) | ARB content, generation and interface language |
| [API languages](docs/api-languages.md) | Request language, account preferences and legal documents |

The Rust API [HTTP contract](../histae-api-rust/docs/http-contract.md) defines routes, DTOs and
authorization. Its [billing guide](../histae-api-rust/docs/store-billing.md) covers store products
and website Stripe integration. The mobile client never calls administrator routes.

## Runtime behavior

Feed, Matches and Profile keep their views and loaded data alive for the session. Navigation does
not reload them systematically. Manual refresh, writes, relevant server events and language changes
refresh the necessary resources. Messages continue to arrive in real time.

When feed presence expires, the location step appears immediately and readiness is refreshed once
automatically. GPS still requires an explicit user action. The API determines access, quotas,
rewards and subscriptions; local UI state is not proof of a successful operation.

## Checks

```bash
flutter analyze
```

Run existing tests relevant to a change; see [Development](docs/development.md#checks).
Documentation-only edits do not require Flutter tests. Simulated tests and local builds do not
verify real SMS, push delivery, advertising, purchases or native platform behavior.

## License

Copyright © 2026 Nicolas GERMANI. Proprietary software, all rights reserved:
see [LICENSE.md](LICENSE.md). Bundled fonts retain their own licenses, linked in the design system.
