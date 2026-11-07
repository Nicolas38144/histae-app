# Product flows

[Documentation](README.md#documentation) · [Architecture](ARCHITECTURE.md) · [Roadmap](roadmap.md)

The [Rust contract](../histae-api-rust/docs/http-contract.md) owns access rules, limits and DTOs.
This guide describes user behavior; cache, retries and ownership belong in Architecture.

## Registration and consent

Registration collects profile, preferences and explicit consent choices before phone/OTP.
Drafts stay in memory until verification; closing the flow discards them. Returning users go
directly to phone verification. Birthdate uses an adult-only calendar; sex defaults to male.
Preference sliders start at ages 18–50 and 50 km. France (+33) is the supported phone selector.

Both flows use generic OTP acknowledgement. An already registered sign-up number or unknown
sign-in number opens code entry without sending SMS. Neither response reveals membership or
proves delivery. Resend cooldown remains separate from code verification.

Public legal metadata comes from `GET /api/legal/documents`. After verification the app checks
it again, saves choices and permitted profile/preferences, and preserves an existing account.
Interrupted saves resume manually after checking server state. Terms acceptance and privacy-notice
acknowledgement are required; sensitive-data and location agreements are separate and withdrawable.
Sex/preferences are omitted without sensitive-data agreement. Native GPS permission is separate.

Withdrawal can remove affected fields or presence and make discovery unavailable. Privacy,
logout, export and deletion remain accessible where authorized. Document acceptance is not yet
atomic with publication; see the roadmap.

## Profile and discovery

Profiles contain identity, biography, traits and up to three ordered answers. Saving answers
replaces the whole list. Public projections show approved text; owners see text moderation state.
A private photo is required for discovery, becomes available after upload, and stays hidden from
the feed. Camera/gallery selection opens a local portrait crop with drag/pinch, accessible zoom,
rotation/reset and a live circular avatar preview. Confirming stages the framed photo; only explicit
Save uploads it. Processing strips metadata and bounds decoded dimensions and final JPEG size.
Cancelling preserves an earlier staged choice; replacement affects authorized reveals.
The owner preview reuses public components without inventing a distance or partner photo.

Readiness explains missing steps. Requesting location obtains one fresh position, with no
background tracking. Expired presence hides old candidates and refreshes readiness once;
GPS still requires a deliberate action. Pause hides new discovery/likes while retaining chats.

Feed presents first name, age, server distance, biography, traits and answers. Three visible
seconds unlock like/pass; a thin bar shows progress and pauses when hidden. Double tap likes;
an upward gesture at the end passes. Buttons provide equivalent actions. Confirmed decisions
animate briefly into the next profile; reduced motion uses static feedback. Reporting/blocking
remain immediately available. Only a server-confirmed reciprocal decision creates a match.

## Conversations and photos

`active`/`confirmed` matches allow sending; `awaiting_continuation` keeps history readable.
Ended/inaccessible matches leave the list. Search and archives use loaded rows, with explicit
pagination. Unread counts appear on match rows; receipts depend on visible received messages.
The composer stays editable during queued sends; uncertain retries preserve the original message.
While awaiting continuation, its send action becomes the shared credit/Premium confirmation. An empty
balance opens Credits; an accepted choice waits for the partner. Server events reopen composition
and remove the continuation section from match details once both have agreed.

Confirmed chats archive after 10 days without a new message, receive a warning at day 23 and are
deleted with their messages at day 30. A new message unarchives/resets the deadline without another
credit; reading, login and replay do not. Free and Premium follow the same rule.

Mutual photo agreement is confirmed by the API. Either participant can withdraw: both photos
and thumbnails disappear while messages and the other agreement remain. Re-agreement can restore
sharing. Replacing a photo updates mutually authorized matches. Thumbnails appear beside the name;
tapping the name opens the profile. From shared-photo details, Back returns directly to chat.
Ending a match and blocking are distinct; unblocking does not recreate it.

## Credits, ads and subscriptions

Continuation confirmation rereads the match/quota and presents the applicable cost. A changed
offer needs renewed confirmation. The API owns balances, reservations and entitlements.

Matches shows a compact credit disclosure linking to Credits. Included/ad balances remain separate;
the next renewal uses local date/time, while the API owns the Monday reset. Once included credits
run out, eligible Free users can watch an optional video if stock has room. Reaching the weekly
continuation cap takes priority and opens subscriptions; new reward videos are blocked. Existing
proofs can settle. Reservations alone do not count as confirmed continuations.

UMP handles ad preferences separately; only server reward validation grants credit.
Google Play/StoreKit supply purchase UI and prices, with server verification before completion.
Restoring purchases preserves the Histae owner. Monthly is the initial carousel selection.
Existing Stripe subscriptions are website-managed; mobile offers no Stripe Checkout.

## Help, notifications and privacy

A guide opens at the first usable feed and can reopen from Help and contact in Profile. Local
encrypted drafts recover unsent messages and unpublished answers, excluding biographies, and clear
on logout. Submitted messages are not restored as fresh drafts. Abrupt termination may interrupt
a pending local write.

Push needs platform configuration, permission and API registration. OS alerts are for background
delivery; open-app messages/counters use realtime state. Removing a push device does not revoke
its login session. Support opens the email app using `SUPPORT_EMAIL`.

Account notification choices cover messages, matches, continuations, photo sharing, deadlines and
account/security events. Discreet display hides first names. The chat menu can mute one conversation
for an hour, until tomorrow's local midnight or indefinitely; unread counters remain available.
These choices persist across devices in the API and never override device permission/opt-outs.
Android exposes matching system channels for sound/vibration; iOS opens app settings. There are no
scheduled quiet hours. The matching API migration and worker deployment are required.

Privacy groups documents, choices, sessions, devices, blocks, correction requests, export and
deletion. Requests require a precise description and do not immediately modify data. Exports use
temporary files and explicit sharing; external copies cannot be recalled. Confirmed deletion
acceptance closes access while cleanup proceeds; a lost response closes local access without
claiming erasure finished.
