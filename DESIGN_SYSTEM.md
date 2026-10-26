# Histae design system

[Documentation](README.md#documentation)

The mobile app shares the website's open-book identity, night-blue palette, lavender and apricot
accents, and serif headings. Dark mode is the default.

## Voice and content

Use simple, welcoming copy and concrete actions. French uses the formal form of address.
Ordinary messages should describe what a person can do, without exposing transport internals.
An uncertain save, purchase or reward stays uncertain until confirmed.

Give long biographies and answers room to breathe. Do not rewrite or automatically translate
personal content. Previews use clearly identified fictional profiles and conversations.
Empty states provide a useful action without fabricating activity.

## Colors and typography

[HistaeTokens](lib/core/theme/histae_tokens.dart) and the [Flutter theme](lib/app/theme.dart)
are the implementation references.

| Role | Value |
| --- | --- |
| Main background | `#0D1421` |
| Secondary background | `#141D2D` |
| Panel | `#1A2231` |
| Main text | `#F9F7F2` |
| Secondary text | `#C6C1D3` |
| Lavender | `#B69CFF` |
| Apricot | `#F09A82` |
| Primary action | `#F2A48C` → `#D8B3F7` gradient with dark text |

Inter is used for body text, forms and buttons; Source Serif 4 for headings. Respect screen width
and system text size. Panels generally use thin borders and a 20 px radius; primary actions use
a pill shape. Secondary buttons use a subtle lavender surface, light outline and 16 px corners.
Space stacked actions so their hierarchy stays clear.

Use `HistaeButton` for primary, outlined and text actions, including icon variants. The shared
component reserves 8 px above and below each action (16 px between adjacent buttons). Keep
horizontal gaps in rows/wraps explicit. Toolbar icons, steppers and plan selectors retain their
compact controls; do not replace external spacing with larger label padding inside a button.

Bundled font licenses: [Inter](assets/fonts/inter/OFL.txt) and
[Source Serif 4](assets/fonts/source_serif_4/OFL.txt).

## Logo and launch

The logo is the open book, with the Histae name as an optional signature. The product source is
[histae-logo.svg](assets/branding/histae-logo.svg); variants and PNGs live in
[assets/branding](assets/branding/). Native launcher icons show the book with platform-appropriate
padding. Android also has adaptive and monochrome layers.

`AppOpening` separates **H.** to reveal **istae**, then shows the book. The 1,480 ms animation runs
on mount, skips reduced-motion mode and finishes on suspension without resetting application state.
The [iOS launch guide](ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) covers native images.

`tool/generate_brand_assets.cjs` uses Node.js, Sharp and local SVG sources under
`pictures/logos/nouvelle-da/02-les-pages/`. It regenerates product/native sizes; `--site` also exports
website assets. Review generated assets before using them in a release.

## Main screens

Feed gives priority to profiles, without commercial buttons. Reading to the end of a long profile
must not accidentally pass it. Expired presence goes directly to the location step while readiness
refreshes; the person still chooses when to request GPS.

Matches shows a compact, scrollable credit card with an explicit view-credits action and arrow.
Free users see available included/ad credits and Videos; Premium users get an appropriate message
without a video button. A failed or unknown quota read must not appear as a zero balance.

Conversation receipts stay at the bottom right of outgoing bubbles in 11 px metadata:
a small neutral check for Sent, and a lavender double check for Read, with translated labels.
Read state always comes from the API. Dates are hidden until a message is tapped, then appear
above that bubble for three seconds without moving the history. Scrolling, another tap or
leaving the conversation dismisses the date. Long-press text selection remains available.

Profile groups the introduction, answers, feed preview, account details, pause mode and settings.
Its subscription entry shows Premium for Free or the subscription-management label for Premium,
with neutral loading state. The copyable account UUID appears only in the private profile.

Photo management places Take a photo above Choose a photo. Both actions stage an image for
explicit upload. Available photos are described as saved, without approval badges or a pending
verification step. Mutual consent still controls when a match can see the photo.

Answer editing separates the question, text, order and remove/move actions. Replacing the full answer
list is explicit. Sensitive-data and location choices use switches, separate from required terms
acceptance and privacy-notice acknowledgement.

Privacy request choices have plain action labels and an explanation hidden behind a small
disclosure arrow. The selected explanation opens and closes on demand and resets when the
choice changes. Clarify the difference between a request for manual handling, direct export
and account deletion; a request status must not imply that a processing restriction was applied.

## Navigation and accessibility

The Profile / Feed / Matches bar is transparent, with no panel, shadow or separator. Icons are
24 px; the selected icon has a 44 px lavender circle, a label below and a full-tab touch target.
Reduced motion removes the circle transition. System bars remain transparent with appropriate
bottom spacing for scrollable content.

Shared widgets retain disabled states, focus, semantics and keyboard behavior. Keep scrolling and
whole words on small screens, with a keyboard or at 200% text. Chat headers become compact while
details and confirmations remain scrollable. Never globally shrink the person's chosen text scale.

Use [visual previews](docs/development.md#visual-previews) for relevant states and translations.
Native icon masks, fonts and cold starts still need Android/iOS device review.

Subscription offers open on Monthly when available. The horizontal carousel spaces cards apart
and reveals the neighboring cards; the shared coral-to-lavender action gradient identifies
the selected offer, with dark text for contrast.
Previous/next buttons and a localized position label also support navigation. Its height follows
the selected card, including large text; offers appear before subscription maintenance actions.
Feed remains the initial tab at the center.
