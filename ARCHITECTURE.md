# Flutter architecture

[Documentation](README.md#documentation)

The app is organized by feature, with `ChangeNotifier` controllers, constructor injection and
Flutter navigation (`Navigator` and `MaterialPageRoute`). The usual flow is
**view → controller → repository → HTTP client**.

## Responsibilities and ownership

| Layer | Responsibility |
| --- | --- |
| `lib/app/` | Bootstrap, dependency composition, session scope, navigation and global lifecycle |
| `lib/core/` | Configuration, transport, async primitives, localization and shared UI |
| `features/*/presentation/` | Rendering, interactions, navigation and confirmations |
| `features/*/application/` | Observable state, commands, action validation and cancellation |
| `features/*/data/` | Repositories, DTO decoding, cache and native integrations |
| `features/*/domain/` | Shared contracts independent of their concrete implementation |

Core does not import features. Private repositories depend on `AuthenticatedSession`, not
`SessionController`. Exposed collections are protected from external mutation.

`bootstrap` reads the public environment, registers font licenses and attempts to clean interrupted
private exports. `AppDependencies` composes services; `HistaeApp` disposes the dependencies it owns.
`SessionGate` selects the public, onboarding or private flow from confirmed session state.

During sign-up, `SessionGate` owns `RegistrationController` and keeps its flow visible while OTP
establishes the session. `RegistrationDraft` holds only form values in memory; the profile and
preferences widgets own their text controllers. `RegistrationLegalRepository` loads public document
metadata, while the registration controller coordinates authenticated consent/profile writes and
explicit recovery. `OtpForm` is shared with returning sign-in through an authentication callback.
The normal private scope opens only after sign-up finishes or the user explicitly leaves it.
`OtpController` separates resend deadlines from verification rate limits; `OtpForm` only renders
those states. `AuthRepository` decodes the server's resend receipt. Neither UI nor controller
infers account membership from accepted requests.
The OTP summary exposes only the country prefix and final two digits. An uncertain send may be
retried with its original intention; an incorrect code never offers a send replay, and an uncertain
verification requires a deliberate new code.

`AppPrivacyShield` hides the entire navigator, overlays and opening animation while the app is
inactive, without disposing drafts or controllers. Focus, touch and accessibility are excluded.
Android sets `FLAG_SECURE` before the first Flutter frame and disables Recents snapshots on API 33+.
iOS `SceneDelegate` owns a native `ScreenPrivacyShield` window for synchronous background masking
and screen-capture detection (scene traits on iOS 18+, legacy screen notifications on iOS 15–17).
It never becomes key. Still screenshots cannot be blocked through supported iOS APIs.

The catalogue owns `SubscriptionPlanCarousel`, reused by its public read-only page and billing's
subscription plans. It owns selection and measured card heights only; catalogue loading and
purchase actions remain in their respective controllers.

`MainShell` owns Feed, Matches and Profile controllers. Its `IndexedStack` retains the three views
and scroll state; its session resource key rebuilds the private scope when access changes.
A page disposes a controller it creates. A received controller remains owned by its parent.
Suspending activity and disposing resources are distinct operations.

## Cache and reads

`SessionController` owns authentication and request authorization. Domain snapshots belong to the
repositories composed by `SessionRepositories`; the public catalogue has a separate language-aware cache.
`ReadSnapshots` holds at most 128 validated entries per instance in memory and retains their original
read timestamp. `ReadPolicy.cached` reuses a snapshot; `ReadPolicy.refresh` requests a new one.

| Trigger | Behavior |
| --- | --- |
| Main-flow startup or first detail opening | Initialize missing controller data |
| Tab change or foreground return | Reuse loaded data without a systematic reread |
| Manual refresh or requested pagination | Perform an explicit read |
| Mutation, relevant server event or cost confirmation | Refresh the affected resources |
| Feed presence expiry | Hide stale candidates, show the location step and refresh readiness once |
| Other resource deadlines | Disable or evict expired state; refresh only as defined by that flow |

Writes invalidate affected resources before and after the call, including lost responses.
Targeted invalidation rejects late fills without clearing unrelated snapshots. A failed refresh
must not resurrect an old success. Account, consent, language and access changes purge the relevant
caches. Canceled responses, errors, exports and SSE streams are not reusable snapshots.

Feed expiry retains the last server diagnostic for a coherent location prompt. It never requests
GPS automatically. The already-checked deadline prevents repeated reads when the server returns
the same expired timestamp. An expired readiness response cannot load a stale candidate batch.

## Sessions, concurrency and persistence

Refresh-token rotation is serialized. Secure storage is written and reread before a new session
is published. An uncertain rotation closes access rather than reusing an old refresh token.
Logout and account deletion also use durable barriers.

A permitted request may retry once after a `401` confirming access-token expiry. There is no universal
network retry for mutations. Retried intentions retain their idempotency key, content and language.
`RequestCancellation`, revisions and generations prevent late responses from restoring private data.
`SerialExecutor` orders local operations; `RetryTicker` updates countdowns while respecting `Retry-After`.

| Data | Storage |
| --- | --- |
| Access token, profiles, messages, coordinates, drafts and signed URLs | Flow/session memory |
| Refresh token and rotation/logout state | Secure storage bound to the API origin |
| Push preference and registration metadata | Minimal owner-bound secure entries |
| Explicit interface language | Device preference independent of the account |
| Private export | Dedicated temporary file, cleaned after use |

Native store SDKs own their purchase lifecycle. The app does not persist a browser Checkout attempt.

## Real time, messages and private photos

`RealtimeHub` shares SSE transport among matches, notifications and subscriptions. Covered routes
suspend the relevant main-flow event handling without creating another transport. Private access
loss or owner disposal stops the stream.

Events trigger the authorized reads required by each flow. Notifications are not authorization
proof: opening one verifies the session, collection and history. `MessageOutbox` retains drafts
and immutable send intentions. Read receipts require a received message visible in the foreground.

`SignedPhotoLoader` downloads to memory without Bearer credentials or redirects, with a 5,000,000-byte
limit and a fifteen-second timeout. Access is checked before display. Closing, losing access or
reaching the display deadline evicts the image. Reopening does not extend the four-minute deadline
measured from the resource read.

## Credits and provider adapters

Profile and Matches share `ContinuationController`. It initializes quota once and refreshes after
explicit requests, spending, rewards or confirmed subscription changes. The continuation cost is
rechecked before acceptance; the client never invents a credit debit or grant.

`RewardedVideoGateway` isolates UMP/AdMob; `RewardTracker` follows the server intent. Only server
validation grants a reward. `BillingController` operates on immutable values and `BillingGateway`;
`NativeBillingGateway` alone handles Apple/Google SDK objects. Purchase verification precedes
completion, and unverified purchases remain available for a safe retry or restoration.

## Presentation and language

The [design system](DESIGN_SYSTEM.md) defines the shared visual behavior. `AppOpening` owns only the
opening presentation; session initialization and navigation continue independently.
`LocaleController` owns device language and `AccountLanguageBinding` connects it to the verified
account. A separate localization revision refreshes reads without discarding drafts or mutations.

See [Localization](lib/core/l10n/README.md), [API languages](docs/api-languages.md) and
[Development](docs/development.md) for the corresponding contracts and checks.
