# Product flows and integration rules

[Documentation](README.md#documentation) · [Architecture](ARCHITECTURE.md) · [Roadmap](roadmap.md)

The Rust API [HTTP contract](../histae-api-rust/docs/http-contract.md) owns DTOs, errors, limits and
authorization. The mobile app contains neither administration UI nor `/api/admin/*` calls.

## Account access and consent

Registration proceeds through profile (first name, birthdate, sex and biography), preferences,
consent choices, then French phone/SMS OTP verification. The draft stays in flow memory between
steps; no private field or consent is sent before verification. Closing the flow or process discards
unsaved values. Returning sign-in opens phone verification directly. Both flows share the same OTP
implementation; there is no separate password-based registration endpoint. An accepted SMS request
does not prove delivery; a lost verification result requires a new code.

Sign-up uses a calendar-only adult birthdate picker and defaults sex to male. Preference sliders
start at ages 18–50 and 50 km, with one-unit minus/plus buttons disabled at the API bounds or the
opposite age limit. Phone entry uses the France (+33) selector and normalizes national typing or
international autofill to E.164. Registration OTP requests include `registration: true`. Every accepted request opens the same
code-entry screen: an already registered number at sign-up, or an unknown number at sign-in,
receives no SMS. HTTP does not query account membership or wait for Sweego: the API atomically
queues an encrypted request for its outbox worker. The generic acknowledgement proves neither
delivery nor authentication. An explicit sign-in action remains available during registration.

The server enforces a shared resend cooldown (60 seconds by default); the mobile displays its
remaining time without disabling code verification. Editing the phone cannot bypass it. A lost
send response is resumed with the same UUID and parameters, never a new background SMS. Global
provider attempt limits default to 100/hour and 500/day in addition to per-phone limits. Deploy
the matching API, schema and outbox worker before relying on these protections.

`GET /api/legal/documents` supplies the current public document metadata, using the same versions,
URLs and language fallbacks as the authenticated consent endpoint. Deploy this API route before the
new registration flow. After verification, the app compares the documents again, saves the explicit
consent choices, then the profile and permitted preferences. Sex and preferences are omitted without
sensitive-data consent. An existing account is preserved rather than overwritten by a sign-up draft.
An interrupted save can be resumed manually without another SMS; uncertain writes are checked by
reading the current server state first. Photos, traits and question answers remain editable from
the profile once the account is created.

Private access depends on the API's current required documents. Terms are accepted and the privacy
notice is acknowledged. New choices are not preselected. Sensitive-data and location agreements
are separate and withdrawable, with their consequences explained. Native GPS permission does not
replace the Histae agreement.

Sensitive-data withdrawal removes the affected fields, including sex/preferences; location
withdrawal removes presence. Discovery may become unavailable while other account settings remain
accessible. Logout, privacy requests, export and deletion remain available where the API permits.

Before saving, the client compares the document version, URL and language against what was shown.
The current PUT does not send an expected version: this precheck cannot guarantee atomicity if a
document changes during the write. A complete guarantee requires an API change.

## Profile and private photo

Profiles are adult-only. Identity/bio updates send the intended field state; preferences are saved
together. Traits and questions come from API catalogues. The owner manages up to three ordered
answers; saving confirms replacement of the entire list, including clearing it. Public projections
show approved text, while the owner sees moderation state.

An approved private photo is required to access discovery and to appear as a candidate. The feed
shows a repair step linking to photo management while a photo is missing or awaiting approval.
Photo writes invalidate feed readiness without introducing navigation-based API reloads.
One private photo can be selected, replaced or removed. Preparation produces an oriented JPEG
without EXIF, limited to 500,000 upload bytes. An uncertain retry keeps its exact bytes and key.
Signed photos are temporary, without disk caching or speculative partner downloads.

The owner's feed preview reuses public components and approved content, without inventing a
distance/photo or allowing a swipe on the owner.

## Feed, location and pause

The server readiness diagnostic identifies missing steps. GPS is requested on demand after the
Histae agreement and native permission; there is no background location tracking or reuse of an
old native reading.

When presence expires, stale candidates disappear and the recent-location step appears immediately.
The app refreshes readiness automatically once, without triggering GPS. Repeated expired server
timestamps do not start a request loop.

Feed shows first name, age, server distance, biography, traits and answers without a photo.
A double tap likes; a separate upward gesture at the end passes. Buttons offer the same actions.
Each profile requires three seconds of visible reading before either action becomes available.
A thin gradient bar fills at the top of the profile and pauses while the feed is hidden or the app
is inactive. Confirmed choices show a brief heart or upward-arrow animation, slide the current
profile upward and bring in the next from below. Reduced motion uses a static feedback symbol
and disables the sliding transition.
Reporting and blocking remain immediately available.
An uncertain choice can only resume with the same target and decision. A match requires a
confirmed reciprocal result from the server.

Pause mode is an account setting shared across devices. It hides new discovery and suspends new
likes/matches while preserving existing conversations. Its API deployment is required.

## Matches, messages and reveal

Server-authorized `active` and `confirmed` matches permit sending. `awaiting_continuation` keeps
history readable and disables composition. Local deadlines disable actions without inventing a
new server state. Message ordering and cursors follow the API.

A lost send response retains text and UUID for an explicit retry. Read receipts apply only to
received messages visible in the foreground. Shared real time refreshes affected resources;
notification navigation verifies access before opening the conversation.

Mutual photo reveal must be confirmed by the API. Losing access, closing the viewer or reaching its
display deadline evicts the signed link and bytes. Reopening does not extend the deadline.
The conversation header offers an explicit photo-sharing action. Each participant can withdraw
their agreement for that match: both photos and thumbnails are hidden, while messages and the
other participant's agreement are retained. A later agreement can restore mutual sharing.
Unconfirmed withdrawal stays hidden locally and can only retry withdrawal, never an old grant.
Replacements use the latest approved profile photo in all mutually authorized matches, with that
behavior explained before agreement. Authorized thumbnails appear beside the name in the match
list and conversation header; they use bounded memory downloads and are purged when hidden.
Ending a match and blocking a person are distinct confirmed actions; unblocking does not recreate
a match. Inaccessible data is purged and late responses are ignored.

## Continuations, credits and rewards

Before a continuation, the app rereads the match and quota, presents the person's cost and sends
the accepted `credit_cost`. It never calculates a successful debit locally. A changed plan or stale
offer requires renewed confirmation; an uncertain retry retains the accepted cost.

Matches distinguishes available included credits, ad credits and the weekly cap. Reservations are
not shown as available. Premium continuations use no credits; read failures are not zero balances.

Videos are optional for eligible Free users. The API intent supplies ad-unit/custom data; UMP
handles ad preferences separately from Histae consent. SDK completion starts tracking, while only
server validation grants the credit.

## Push and billing

Push requires public Firebase options, user enablement, native permission and API registration.
In-app banners remain generic and openings are deduplicated. Removing a push device does not revoke
its login session.

Google Play and StoreKit provide native purchase UI and localized prices. The API supplies store
product identifiers and verifies receipts before purchase completion. Restoration preserves the
purchase's Histae owner. Effective Free/Premium rights come from the API, never a success URL or
SDK status alone. Stripe subscriptions are managed on the website; the app offers no Stripe checkout.

## Privacy and deletion

Privacy groups documents, editable choices, sessions, devices, blocks, rights requests, export and
deletion. Submitting a rights request does not immediately execute it. Private JSON exports are
downloaded temporarily and shared explicitly; cleanup is restricted to app-owned files and cannot
remove copies saved elsewhere.

Deletion requires confirmation and a dedicated token. A `202` closes access and reports cleanup
in progress. A lost response closes local access with an uncertain remote result, without claiming
erasure is finished.

For shared caching and retry rules, use [Architecture](ARCHITECTURE.md). Interface and request
language rules are in [Localization](lib/core/l10n/README.md) and [API languages](docs/api-languages.md).

The public plan catalogue and subscription management share the same adaptive offer carousel,
with Monthly selected initially, visible neighbouring cards and localized offer selectors.
