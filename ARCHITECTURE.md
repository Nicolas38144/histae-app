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

`MainShell` owns Feed, Matches and Profile controllers and the shared page controller.

`SessionRepositories` also owns `DraftController`. Production injects `SecureDraftVault`, while
tests explicitly use an in-memory vault. A typed snapshot holds only pending profile answers
and unsent message text, scoped to the verified account and API origin. Writes are serialized,
debounced while typing and flushed when leaving a form or backgrounding. Sign-out clears memory
and queues deletion after outstanding writes. Account changes never restore a previous owner's
snapshot. Biography, photos and credentials are excluded.

`MessageOutbox` removes persisted text before an HTTP send begins. An uncertain send keeps its
original key in memory and is not restored as a fresh, sendable draft after process death.
`AnswersEditor` restores local inputs without publishing them; saving still uses the explicit
replacement confirmation. `DraftSnapshot` owns decoding and `DraftVault` owns native storage.

`HelpController` owns the device's first-feed-guide flag. Its injected store performs only local
operations. Discovery pauses its reading timer while the initial guide is shown; Help can reopen
the same guide. Match-name search filters loaded snapshots locally and keeps pagination explicit.
The next credit-renewal label converts Monday midnight UTC to the device's locale/time zone;
displaying or updating this date never grants credits or refreshes the API.
At the weekly boundary, a Free quota snapshot becomes unavailable locally and asks for a manual
refresh. Its old ceiling must not keep offering a subscription as though the week had not reset.
`MainTabPager` provides horizontal paging in Profile / Feed / Matches order, synchronized with
the bottom navigation. Its viewport cache initializes and retains all three views at startup,
including their scroll state, without reloading data on a tab change. Offscreen views exclude
focus, touch, semantics and tickers; reading time pauses during page transitions. Pushed detail
routes retain their own gestures. The session resource key rebuilds the private scope when access changes.
The pager increases only its own horizontal touch threshold; each child receives the original
device gesture settings so vertical scrolling and controls keep their usual sensitivity.
`HistaeScaffold` uses the same solid theme surface for tab and detail backgrounds.
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

On an explicit location request, Android's fused provider can show the native service-activation
dialog. `DeviceLocation` must not reject disabled Android services before the provider starts;
the platform resolves that setting after permission checks. Acquisition remains a cancellable,
single-fix stream with no foreground service, a zero initial cache age on Android and the
existing 25-second deadline. Refusal or unavailable resolution shows feedback and a settings
action next to the location step. iOS retains the disabled-service settings fallback.

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

The conversation name and its profile menu entry share one navigation action. `PartnerPage`
renders the selected match's existing public data through `FeedProfileContent`, also used by
discovery and the owner's preview. Opening it does not reread the API or discard the message
draft. Distance is omitted because the match projection does not supply it.

`SignedPhotoLoader` downloads to memory without Bearer credentials or redirects, with a 5,000,000-byte
limit and a fifteen-second timeout. Access is checked before display. Closing, losing access or
reaching the display deadline evicts the image. Reopening does not extend the 50-second deadline
measured from the resource read. This leaves a margin before the API’s 60-second signed URL expiry.

`PartnerPhoto` owns full-size photo rendering for both the match profile and `PartnerPhotoPage`.
It observes match access, route visibility, app lifecycle and the original read deadline. A
covered route cancels its download and purges the decoded image; late bytes cannot restore it.
Manual photo refresh remains an explicit authorized read.

`MatchPhotoAvatar` applies the same 50-second resource deadline to authorized thumbnails. It
downloads through `SignedPhotoLoader`, never through a persistent network-image cache, and purges
on hidden routes/tabs, backgrounding, withdrawal or replacement. `ContinuationController` keeps
grant and withdrawal retry intentions distinct. `MatchAccess` owns an immediate local photo
barrier until a fresh server snapshot confirms withdrawal, so a lost response cannot restore an
old image. Consent and continuation remain independent operations.

## Credits and provider adapters

Profile and Matches share `ContinuationController`. It initializes quota once and refreshes after
explicit requests, spending, rewards or confirmed subscription changes. The continuation cost is
rechecked before acceptance; the client never invents a credit debit or grant.

`ContinuationQuota` derives weekly-limit and video-recovery states from server counters.
Matches, continuation options and credits share those decisions. Presentation routes reuse the
session billing controller and injected catalogue; only confirmed entitlement changes refresh
quota on return. Rewarded-video eligibility checks the same weekly ceiling before starting and
after asynchronous consent/loading steps.

`RewardedVideoGateway` isolates UMP/AdMob; `RewardTracker` follows the server intent. Only server
validation grants a reward. `BillingController` operates on immutable values and `BillingGateway`;
`NativeBillingGateway` alone handles Apple/Google SDK objects. Purchase verification precedes
completion, and unverified purchases remain available for a safe retry or restoration.

## Privacy requests

New requests in the app offer only correction of otherwise uneditable data. Profile edits,
export, account deletion and optional privacy controls keep their dedicated flows. The retired
restriction/objection categories remain readable in history, but the API rejects their creation
and status transitions and the dashboard exposes no processing actions for them.

`PrivacyRequestForm` owns presentation and validation feedback. `PrivacyController` retains the
session-scoped draft and an immutable `RightsRequestIntent` after an uncertain write. Request
`details` and the administrator's public `response` are bounded to 2,000 Unicode scalars. The API
stores them separately from internal notes, and both app and dashboard render them as plain text.
A correction cannot be completed or rejected without a public reply. Closing it records manual
handling; it does not automatically edit arbitrary account data. Existing records without a
message remain readable. Opening a disclosure never submits a request; sending still requires
confirmation. A definitive validation rejection unlocks the draft; a network failure keeps the
original payload for an explicit retry. Session changes clear the draft and pending intention.

API coverage checked from source on 2026-10-26: the historical six types remain readable; new
restriction/objection requests and their status transitions are disabled. Export streams a JSON file, but creating an access or portability
request does not start that export or complete the request. An administrator's completion of an
erasure request schedules full account erasure through the worker. Rectification requests record the administrator’s response and status; closing one does not
automatically edit the data. No additional processing-suspension controls were introduced. Editable profile data has separate self-service endpoints.
This is a source review, not confirmation of production execution; no API tests were run.

## Presentation and language

The [design system](DESIGN_SYSTEM.md) defines the shared visual behavior. `AppOpening` owns only the
opening presentation; session initialization and navigation continue independently.
`LocaleController` owns device language and `AccountLanguageBinding` connects it to the verified
account. A separate localization revision refreshes reads without discarding drafts or mutations.

See [Localization](lib/core/l10n/README.md), [API languages](docs/api-languages.md) and
[Development](docs/development.md) for the corresponding contracts and checks.

## Photo capture and availability

`PhotoPreparer` supports the camera and gallery through the same local preparation
pipeline. Camera capture prefers the front camera. Both sources bound input size,
normalize to JPEG under 500,000 bytes, remove EXIF data and clean picker cache copies.
`PhotoPage` stages the result in memory; capture and selection never upload automatically.
Android interrupted selections are discarded rather than attached to a restored session.

A valid API upload is immediately available without automated content/face analysis.
The wire moderation fields remain supported for manual removal; approval is not presented
as photo verification. Feed readiness still comes from the API and mutual sharing consent
remains required. Private photo views share `privatePhotoLifetime` (50 seconds from the
resource read), with explicit refresh after expiry.

Legal document dates come from the API's optional `document_date` metadata (`YYYY-MM-DD`).
Both public registration documents and authenticated consent records carry the same date.
`ConsentControl` displays it using the interface locale; it never substitutes `updated_at`,
which records the user's consent event. Missing metadata remains explicit rather than inventing
a publication date. A document date alone does not change an existing consent's version validity.

## Reading preferences

`ReadingController` owns device-local prose preferences, separate from account data and the API.
`AppDependencies` injects `SecureReadingPreferencesStore`; startup restores it before the first
frame, and `HistaeApp` owns disposal. `ReadingScope` shares it across routes. The settings sheet
edits typed choices; `FeedProfileContent` renders them without altering the system text scaler.
Local operations are serialized and a delayed restore cannot overwrite a newer choice. Storage
failure leaves the choice usable in memory and allows an explicit retry. No profile text is stored
with these settings.
