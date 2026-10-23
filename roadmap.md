# Mobile roadmap

[Documentation](README.md#documentation) · [Product flows](resume.md)

Track implemented code, deployed API capability and device/provider validation separately.
An implemented screen is not proof that a production service works.

## Implementation status

| Lot | Scope | Client status |
| --- | --- | --- |
| L0 | Contract and preparation | Rust contract remains the source for routes and DTOs |
| L1 | Configuration, transport, navigation and theme | Implemented |
| L2 | OTP, sessions, documents and consent | Implemented |
| L3 | Profile, preferences, answers and photo | Implemented |
| L4 | Location, feed, choices, preview and pause | Implemented, including automatic readiness refresh on expiry |
| L5 | Matches, chat, read receipts and real time | Implemented |
| L6 | Photo reveal, continuations, credits and videos | Implemented, including AdMob/UMP and server reward tracking |
| L7 | Reports, blocks, sessions, privacy rights and deletion | Implemented |
| L8 | Devices and Firebase push | Client integrated; native delivery still needs validation |
| L9 | Catalogue and subscriptions | Native Apple/Google purchases integrated; Stripe belongs to the website |
| L10 | Real integrations and beta readiness | Remaining work below |

Four languages, shared website branding, opening animation and session caching are integrated.
Keep detailed behavior in the relevant guides rather than a dated implementation log or duplicate
route inventory. Use the [Rust HTTP contract](../histae-api-rust/docs/http-contract.md) for exact routes.

## Remaining beta validation

| Area | Required verification |
| --- | --- |
| Android release | Replace debug signing, confirm identity/versioning and prepare store delivery |
| iOS release | Build on macOS; verify signing, Keychain, sharing, permissions and cold start |
| Account/session | OTP delivery, rotation, lost responses, process interruption and account switching |
| Profile/discovery | Upload limits, moderation, pause deployment and one-time expiry recovery |
| Conversations | Two-account messaging, receipts, continuation windows, blocking and reveal |
| Push | Platform options, API/worker provider, APNs, permission, background/cold-start delivery |
| Rewarded videos | Published UMP message, test devices, delivery, signed reward callback and quota refresh |
| Purchases | Sandbox/Play products, verification, completion, restore, interruption and delayed events |
| Accessibility | Long biographies, four locales, 200% text, keyboard, small screens and native icon masks |
| Privacy/release | Reviewed documents, provider disclosures, support and beta distribution requirements |

The mobile consent precheck is not atomic with document publication. Track an API-side version
precondition before claiming a complete guarantee. Local flags and provider consoles are not
evidence of deployed capability.

## API and delivery dependencies

Check the deployed contract, pause/language support, private storage, moderation, outbox and
maintenance for the intended release. Provider webhooks are called by providers, never by Flutter.
Backend health checks do not replace user-flow errors or prove provider success.

Store purchase setup and website billing are covered by the API's
[billing guide](../histae-api-rust/docs/store-billing.md). Website Checkout/portal validation belongs
to that release, not a mobile browser-payment integration.

## Completion criteria

For each enabled flow, record its environment, app/API version, check and result. Include loading,
empty, failure, uncertainty and access-loss states according to risk. A simulated test, analyzer
pass or Android build does not validate a real provider or iOS.

Use [Development](docs/development.md) for commands and [Configuration](docs/configuration.md) for
public settings. Update this backlog when scope or remaining validation changes; do not retain
completed task histories in the README.
