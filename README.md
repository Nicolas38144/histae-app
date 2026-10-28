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
| [Licensing](docs/licensing.md) | Audit-only source access, dependency licenses and review limits |

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

## Source access and licensing

Copyright © 2026 Nicolas GERMANI. Original Histae code is proprietary and publicly available only
for inspection and security audits. Reuse, modification outside an audit, redistribution and use
in another project or service are prohibited for commercial and non-commercial purposes without
prior written permission. See [LICENSE.md](LICENSE.md) for the limited audit permission and
applicable exceptions. External contributions are not accepted.

Third-party dependencies, SDKs and fonts retain their own licenses; these restrictions do not
override their rights or notices. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Confirmed conversation inactivity

After 10 days without a new message, a confirmed conversation is archived but stays accessible.
Both participants receive a warning at day 23; the match and messages are deleted at day 30.
A new message unarchives it and resets the deadline without another continuation credit.
Signing in, reading and replaying a send do not reset it. The rule is identical for Free and Premium.
The API fields `archived` and `inactivity_expires_at` drive presentation; `confirmed` remains the
business status. Archive rules are always available in Help and appear in Matches once a confirmed
conversation exists.
