# Architecture

[Documentation](README.md#documentation) · [Product flows](resume.md)

## Layers and ownership

Dependencies flow from `presentation` to `application`, `data` and `core/network`.
Widgets render state and collect input; controllers coordinate flows; repositories handle API
contracts and cache policy. `core` must not import features. Business authorization belongs to the
[Rust API](../histae-api-rust/docs/http-contract.md); mobile never calls administrator routes.

`AppDependencies` creates shared dependencies and `HistaeApp` disposes them. `SessionRepositories`
owns account-scoped repositories, snapshots, drafts and the realtime hub. Routes dispose the
controllers they create, never injected shared objects. Cancellation follows the same ownership.

`MainShell` retains Profile, Feed and Matches, with Feed initially selected. Hidden pages use
`Offstage`/`TickerMode`; tab changes preserve views and do not trigger systematic API reads.
Localization revisions are separate from session/resource identity.

## Reads and invalidation

`ReadSnapshots` holds at most 128 typed entries, preserving the original read time. Cached reads
reuse them; explicit refresh requests new state. Identical requests coalesce only when their key
and cancellation owner match. Independent consumers retain independent cancellation.

Writes invalidate affected snapshots before and after the request, including uncertain outcomes.
Generation checks reject late responses. Errors, cancellations, exports and SSE streams are not
cached. Account/access changes clear private state; language changes invalidate localized reads.

Refresh only affected resources after writes, relevant server events or a known deadline. Manual
refresh belongs to Feed; other screens expose recovery only after failure or an uncertain outcome. Expired feed presence immediately hides stale profiles and exposes the location step;
readiness refreshes once, without automatic GPS or a repeated-expiry request loop.
`DeviceLocation` obtains one fresh cancellable fix with a 25-second timeout. Android can request
native location activation; iOS and unsupported devices offer settings.

## Authentication and writes

Registration keeps profile, preferences and consent choices in memory until phone verification.
Then it rechecks legal metadata and saves permitted fields, preserving an existing account.
The consent precheck compares version, URL and language but cannot make document publication and
acceptance atomic without an API version precondition.

OTP send intentions freeze phone, language and UUID. Resend cooldown and verification limits are
separate. An uncertain send retries the same intention; an uncertain verification requires a new
code. Generic acceptance proves neither account existence nor SMS delivery. Display only the
phone prefix and last two digits.

Refresh rotation persists its credential and recovery UUID before sending, and saves the new
pair before publishing access. Temporary failures preserve the attempt; definitive rejection
clears access. Logout/deletion barriers prevent stale responses restoring a session. See
[Session recovery](docs/session-recovery.md) for the protocol and deployment order.

Mutations keep immutable intentions and idempotency keys until resolved. Do not automatically
repeat writes after a timeout or treat a local success state as server confirmation.

## Local state and messages

Encrypted drafts are scoped to account and API origin. Debounced, serialized writes flush on
lifecycle changes; logout clears them. Only unsent messages and unpublished answers persist,
excluding biographies, photos and tokens. Submitted message intentions remain in memory and
must not reappear as fresh sendable drafts after restart.

Messages use a FIFO outbox while the composer remains editable. Acknowledgement requires the
confirmed server message. Retries retain the original text, language and key. Realtime updates
merge silently without rebuilding the composer, showing a loading bar or disturbing focus.

`RealtimeHub` shares one SSE connection between matches, notifications and subscription state.
Relevant events invalidate only affected resources; reconnection resynchronizes state. An unrelated
match event must not reload the current history. Notification navigation rechecks authorized access.
Read receipts apply only to received messages visible in the foreground.

Match deadlines disable actions locally and trigger one server confirmation when necessary.
Ended/inaccessible rows disappear immediately. Archive/search views reuse loaded snapshots;
explicit pagination loads further rows. Server fields remain authoritative for inactivity.

## Private photos

`PartnerPage` reuses the selected profile projection. Opening it from shared-photo details replaces
that route so Back returns directly to the conversation and preserves its draft.

`SignedPhotoLoader` accepts HTTPS, sends no Bearer token, rejects redirects, caps downloads at
5 MB and times out after 15 seconds. Full-size photos are route-owned, remain alive while scrolling,
and are evicted when covered, backgrounded, closed or no longer authorized. Signed-link expiry
limits new downloads; it does not expire already authorized pixels by itself.

`PrivatePhotoCache` shares foreground thumbnails between list and conversation: at most 48 entries
and 8 MiB of encoded data, with shared providers/downloads and LRU eviction. Backgrounding, logout,
withdrawal, replacement, access loss and deadlines purge affected photos. An unconfirmed withdrawal
is an immediate local barrier: stale grant responses cannot restore images.

Use the snapshot's original timestamp for the 50-second download window of a 60-second URL.
A stale/rejected URL permits one authorized renewal, without rereading unchanged message history
or entering a retry loop. Private photos never use disk caching or speculative partner downloads.

Camera/gallery selection stages an oriented, EXIF-free JPEG of at most 500,000 bytes. Upload is
explicit; an uncertain retry preserves the bytes and key. Discard interrupted Android capture copies.
Photo availability comes from the API; do not use its compatibility moderation status as a review
step. Biography and answer moderation remain separate.

## Native adapters and privacy

`RewardGateway` handles UMP/AdMob; `RewardTracker` follows the server reward intent. SDK completion
alone grants no credit. Continuation confirmation rereads match/quota and retains the accepted
cost; only the server determines balances, eligibility and entitlements.

Billing controllers isolate store SDKs from screens. The API supplies product identifiers and
verifies ownership before purchase completion. `SubscriptionPlanCarousel` owns selection/layout,
not loading or payment decisions. Subscription events refresh quota without reloading chat history.

Push registration requires complete public options, verified account setup and native permission.
First-use prompting does not override a refusal, manual opt-out or remotely removed device.
Foreground activity uses realtime state; OS alerts are for background delivery.

Android uses `FLAG_SECURE` and Recents masking. iOS masks background/app-switcher and recording
content; it cannot globally prevent still screenshots. Do not use secure-text-field workarounds.

Privacy requests submit corrections for data unavailable in self-service; historical limitation
and objection requests remain readable only. Uncertain submissions retain their exact intention.
Messages/replies are plain text, limited to 2,000 Unicode scalars. Closing a request does not itself
modify arbitrary account fields. Export cleanup touches only app-owned temporary files.

[Localization](lib/core/l10n/README.md), [API languages](docs/api-languages.md) and the
[design system](DESIGN_SYSTEM.md) define the remaining shared conventions.
