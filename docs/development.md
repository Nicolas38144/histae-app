# Development

[Documentation](../README.md#documentation) · [Architecture](../ARCHITECTURE.md)

## Working conventions

Keep interface copy in all four ARB catalogues, decisions in controllers/repositories, and
ownership/cancellation explicit. Use fictional accounts and simulated providers in tests/previews.
Never log private data or call admin routes from mobile.

Do not run Git commands or recreate environment example files. Delete files only within explicit
cleanup scope, with evidence they are obsolete. Suggest commit messages in English. Do not execute
new or modified `.sh` scripts during local verification.

## Refresh controls

Feed keeps manual refresh. Remove routine reload buttons and pull-to-refresh elsewhere; use writes,
server events, known deadlines and foreground recovery. Preserve explicit purchase restoration,
uncertain-write recovery and failed-read retries. Reward verification is available after automatic
polling stops; open privacy requests retain tracking because dashboard replies have no realtime event.
Session/block/device reloads and photo-preview renewal appear only when recovery is needed.

## Checks

Format changed Dart files, then check formatting and analysis:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
```

Run existing suites for affected risks; avoid tests that only mirror cosmetic changes.
Documentation-only changes need no Flutter tests. Run Flutter checks/builds serially.

| Area | Relevant suites in `test/` |
| --- | --- |
| Sessions/OTP | `session_test.dart`, `auth_widget_test.dart`, `otp_test.dart` |
| Cache/navigation | `read_snapshots_test.dart`, `cache_lifecycle_regressions_test.dart`, `cached_conversation_test.dart` |
| Feed/location | `discovery_test.dart`, `discovery_pause_test.dart`, `device_location_test.dart`, `feed_reading_delay_test.dart` |
| Photos/privacy | `photo_crop_test.dart`, `profile_widget_test.dart`, `photo_sharing_test.dart`, `continuation_test.dart`, `private_photo_cache_test.dart`, `private_photo_test.dart`, `match_profile_test.dart` |
| Messaging/matches | `conversation_updates_test.dart`, `matches_inactivity_test.dart`, `matches_visibility_test.dart` |
| Native boundaries | `billing_test.dart`, `store_updates_test.dart`, `app_privacy_shield_test.dart` |
| Notifications | `notification_preferences_test.dart`, `notifications_test.dart`, `notification_navigation_test.dart` |
| Localization | `localization_test.dart`, `api_language_test.dart` |

For example: `flutter test test/session_test.dart test/auth_widget_test.dart`.
For cache/photo work, verify no redundant list/chat downloads, unrelated events or URL renewals
reloading history, while withdrawal/backgrounding still purge images. Profile Back must preserve
the chat draft. Report checks actually run; simulations do not validate native/provider behavior.

After ARB changes, run `flutter gen-l10n`; native permission copy also needs the
[localization generator](../lib/core/l10n/README.md#native-resources).

## Visual previews

`tool/preview_*_test.dart` renders real widgets with fictional data into `build/previews/`.
Set `FLUTTER_ROOT` to the SDK when fonts/icons require it. Review the images, including long
translations, 200% text, keyboard layouts and insets against the [design system](../DESIGN_SYSTEM.md).

| Preview | Purpose |
| --- | --- |
| `preview_brand_test.dart`, `preview_localizations_test.dart` | Shared visuals and translations |
| `preview_billing_test.dart`, `preview_benefits_test.dart` | Offers, subscription/profile/credit states |
| `preview_preferences_test.dart`, `preview_help_test.dart` | Forms and safety/help links |
| `preview_message_queue_test.dart` | Pending dots, receipts, composer limit and update gate |
| `preview_continuation_test.dart` | Credit/Premium continuation, automatic confirmation, empty balances and refresh controls |
| `preview_feed_test.dart`, `preview_reading_test.dart` | Feed actions and Aa settings |
| `preview_photo_reveal_test.dart` | Match, chat, photo consent and withdrawal |
| `preview_photo_crop_test.dart` | Local crop controls, live avatar and staged profile previews |
| `preview_refactor_test.dart` | Navigation, archives/search and profile states |
| `preview_website_test.dart` | Website captures, followed by the site's `scripts/export-app-screenshots.mjs` |

Run a selected tool, for example:

```bash
flutter test tool/preview_brand_test.dart --update-goldens
flutter test tool/preview_feed_test.dart --dart-define=FEED_PREVIEW_ACTION=like
flutter test tool/preview_photo_reveal_test.dart --dart-define=PHOTO_PREVIEW_LONG=true
```

Feed accepts `like` or `pass` and exports 30 fps frames. Photo/reading previews use 15 fps and
write `recording.json`. Photo options: `PHOTO_PREVIEW_PORTRAIT` (default
`pictures/fixtures/fictional-portrait.png`), `PHOTO_PREVIEW_OUTPUT` (default
`build/previews/photo-reveal/`), and `PHOTO_PREVIEW_RECEIPTS_ONLY=true` for stills only.
Labels/touch markers belong to recordings; native screen protections remain enabled.

Encode a 15 fps sequence with even H.264 dimensions:

```bash
ffmpeg -framerate 15 -i build/previews/photo-reveal/frames/%04d.png -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,fps=30" -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart build/previews/photo-reveal/demo.mp4
```

## Builds and device checks

```bash
flutter build apk --debug
flutter build apk --release
```

Use [Android signing](android-release.md) for upload-key recovery and Play bundles. After native
or build changes, install the optimized release with the same certificate over existing data and
test a stopped-process launch. Preserve the targeted Room constructor rule in
`android/app/proguard-rules.pro`: removing it can break WorkManager before Flutter starts.

On representative devices, check:

- Portrait-up and drafts across rotation/interruption. iPad needs full-screen mode; Android large
  displays can override orientation locks under [platform rules](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html).
- Android screenshot/recording rejection and Recents masking (API 24 and 33+). iOS app-switcher and
  recording masks on iOS 15–17/18+; active still screenshots remain possible on iOS.
- Disabled location activation, refusal, permission denial and cancellation. Refusal sends no
  position; iOS/unsupported devices offer settings.
- Camera/gallery permission and cancellation, staged preview without automatic upload, and discarded
  interrupted Android capture. Regenerate localized iOS camera permission resources after copy edits.

Native iOS checks require macOS/Xcode and signing. Keep provider delivery, Keychain, sharing,
APNs, purchases and cold starts in the [release backlog](../roadmap.md); Android/widget success
does not validate them.
