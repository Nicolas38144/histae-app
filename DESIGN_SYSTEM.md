# Histae design system

[Documentation](README.md#documentation)

## Identity and shared components

Use the website's open-book logo, night-blue surfaces, lavender/apricot accents and serif headings.
Dark mode is the default. Colors and dimensions live in
[HistaeTokens](lib/core/theme/histae_tokens.dart) and the [theme](lib/app/theme.dart); avoid copying
values into individual screens. Screen backgrounds stay solid during tab transitions.

Inter is used for body text and controls; Source Serif 4 for headings. Respect both font licenses:
[Inter](assets/fonts/inter/OFL.txt), [Source Serif 4](assets/fonts/source_serif_4/OFL.txt).
Panels generally have thin borders and 20 px corners. Primary actions use the coral-to-lavender
gradient and dark text; secondary actions use a subtle surface and outline.

Use `HistaeButton` for standard actions. It reserves 8 px above and below each button; row/wrap
gaps remain explicit. Toolbars, steppers and offer selectors keep compact controls.

The [book SVG](assets/branding/histae-logo.svg) is the logo; the Histae wordmark is optional.
`AppOpening` reveals the letters from **H.**, then the book, in 1,480 ms. Reduced motion skips it;
suspension finishes it without resetting app state. Launcher icons require platform padding,
including Android adaptive/monochrome layers. See the [iOS launch assets](ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md).

`tool/generate_brand_assets.cjs` uses Node.js/Sharp and SVG sources in
`pictures/logos/nouvelle-da/02-les-pages/`; `--site` also exports website assets.

## Spacing

Use the layout values in `HistaeTokens`: 24 px page insets and section gaps,
20 px standard card insets, 16 px between content blocks, 12 px between paragraphs,
and 8 px for labels and supporting details. Reuse `pagePadding` and `panelPadding`.
Reading/offer/balance panels may keep 24 px insets; compact consent and balance
controls use 16 px. Registration and saved preferences share `PreferenceField`.

Count existing component margins: cards add 8 px above/below and standard buttons
do the same. Two adjacent cards or buttons already have a 16 px gap. Add 8 px
between text and a button when a 16 px visible gap is needed. Put spacing around
standalone photos in their parent rather than hiding trailing gaps inside them.

Chat bubbles, receipts, navigation, carousels, icon backgrounds and crop controls
have deliberately denser geometry. Keep those dimensions, reading line height,
minimum touch targets and safe-area/keyboard insets independent of page spacing.

## Copy and screen hierarchy

Use concrete, welcoming language; French addresses people formally. Explain actions rather than
transport internals. Uncertain saves, rewards and purchases stay uncertain. Preserve personal
text; previews use clearly identified fictional people.

- **Feed:** prioritize long profiles, without commercial buttons. Keep the reading bar visible;
  reaching the end of a biography must not accidentally pass it.
- **Matches:** show conversations before the compact credit disclosure and its explicit credits
  link. Unknown balances are not zero. Place unread counts beneath the row arrow.
- **Chat:** show receipts beneath the last sent/read messages, at bottom right. Pending dots use
  that position. Tapping reveals the date briefly above the bubble; preserve text selection.
- **Profile:** group introduction, answers, preview, pause and settings. Show Premium for Free,
  subscription management for paid users, with a neutral loading state. The account UUID belongs
  only here. Help follows the other settings entries.
- **Photos:** place Take a photo before Choose a photo; both stage an image for explicit upload.
  Do not show approval/pending-review badges. Mutual agreement controls partner access.
- **Privacy:** keep optional switches separate from terms acceptance/privacy acknowledgement.
  Correction requests need a precise message; explanations and request history use disclosures.

## Forms and navigation

Reuse `PreferenceField` and sliders for registration and saved preferences. Full-size headings
and adjacent value badges replace floating captions. Disable steppers at bounds. Saved preferences
keep Save visible but disabled until values change; initial onboarding stays enabled.
Registration and profile editing reuse `BirthdateField`: a calendar-only adult
date selector with localized display and an ISO date sent to the API. Once a
profile exists, first name, birthdate and sex are read-only; only the biography
remains editable here. Identity corrections go through the privacy request
workflow and a separate audited administrator endpoint.

The transparent Profile / Feed / Matches bar has no panel, shadow or separator. Use 22 px icons,
a 38 px selected circle and touch targets of at least 48 px. Feed is the initial center tab.
Horizontal navigation requires a deliberate drag so small drift cannot interrupt vertical reading.
Detail carousels keep their own gestures. Respect reduced motion and system insets.

Subscription offers select Monthly initially when available. Space cards, reveal neighbors and use
the action gradient for the selected selector. Provide previous/next controls and a localized
position label; height adapts to the selected card and text size.

Aa reading settings apply only to profile prose: three sizes/spacings, preview and reset. They
preserve system scaling, current profile and cache; the sheet pauses the reading delay.

Keep disabled/focus states, semantics, scrolling and whole words usable on small screens,
with a keyboard and at 200% text. Never globally shrink system text. Review relevant
[visual previews](docs/development.md#visual-previews), then native masks/fonts on devices.
