# Development and verification

[Documentation](../README.md#documentation)

## Working conventions

Keep UI copy in the four ARB catalogues and business decisions in controllers/repositories.
Preserve dependency ownership and cancellation when changing a flow; see [Architecture](../ARCHITECTURE.md).
Use synthetic accounts and provider responses in tests and previews. Never log private data or
call administrator routes from the mobile app.

Do not run Git commands or recreate environment example files. Remove files only within an explicit
cleanup request, with evidence they are obsolete. Provide proposed commit messages in English.
Do not execute newly created or modified `.sh` scripts as part of local verification.

## Checks

Format the changed Dart files and analyze the project:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
```

Use tests for meaningful risks such as session isolation, sensitive data, uncertain writes and
payments. Run the relevant existing suite rather than testing every visual or documentation change.

| Change | Example focused command |
| --- | --- |
| Session/cache behavior | `flutter test test/read_snapshots_test.dart test/cache_lifecycle_regressions_test.dart` |
| Feed expiry, location or pause | `flutter test test/discovery_test.dart test/discovery_pause_test.dart` |
| Native location activation, refusal and cancellation | `flutter test test/device_location_test.dart test/discovery_test.dart` |
| Photo readiness, withdrawal and private thumbnails | `flutter test test/photo_sharing_test.dart test/continuation_test.dart` |
| Conversation profile, cached navigation and full-size photo privacy | `flutter test test/match_profile_test.dart test/cached_conversation_test.dart` |
| Feed reading delay and transitions | `flutter test test/feed_reading_delay_test.dart` |
| Native billing | `flutter test test/billing_test.dart` |
| Interface/request language | `flutter test test/localization_test.dart test/api_language_test.dart` |
| Screen privacy and OTP recovery | `flutter test test/app_privacy_shield_test.dart test/otp_test.dart test/auth_widget_test.dart` |

Tests use simulated providers. State exactly which checks ran and distinguish them from actual
device/provider validation. The current release backlog is in the [roadmap](../roadmap.md).

## Translations

After editing the catalogues:

```bash
flutter gen-l10n
```

Do not hand-edit generated Dart messages. When changing native permission copy, also follow the
[localization guide](../lib/core/l10n/README.md) to regenerate iOS resources.

## Visual previews

`tool/preview_*_test.dart` renders real widgets with synthetic content under `build/previews/`.
For example:

```bash
flutter test tool/preview_brand_test.dart --update-goldens
```

Some tools require `FLUTTER_ROOT` to point to the SDK to load platform fonts. Inspect the actual
images, long biographies and translations, 200% text, keyboard layouts and system insets.
Review the [design system](../DESIGN_SYSTEM.md) before changing shared components or brand assets.

`flutter test tool/preview_feed_test.dart` exports a populated feed and 30 fps PNG sequences for
like/pass demonstrations under `build/previews/feed/`. Touch markers belong to the recording only.
Use `--dart-define=FEED_PREVIEW_ACTION=like` or `pass` to render one sequence.

`flutter test tool/preview_photo_reveal_test.dart` renders the real match, conversation, consent,
photo and withdrawal screens and a 15 fps frame sequence in `build/previews/photo-reveal/`.
Supply a fictional portrait with `--dart-define=PHOTO_PREVIEW_PORTRAIT=<local PNG path>` (the
default points to the delivered preview under `pictures/previews/photo-reveal-2026-10-25/`).
The other participant's agreement is simulated; no provider or production API is contacted.
Native screen protections stay enabled. The preview label and touch markers belong only to the
recording. Add `--dart-define=PHOTO_PREVIEW_LONG=true` for a longer tour covering credits,
conversation details, message composition, the match profile before/after photo consent and
the actions at the bottom of the photo screen.
Use `--dart-define=PHOTO_PREVIEW_OUTPUT=build/previews/<name>` for a separate export directory.
The conversation and match-list preview share the same synthetic message history.
Each export writes `recording.json` with its frame count, capture rate and duration.
For receipt screenshots only, use `--dart-define=PHOTO_PREVIEW_RECEIPTS_ONLY=true`.
This skips video frames and exports sent/read states, the tapped message date and its dismissal.
Encode frames with FFmpeg, padding odd dimensions for H.264:

```bash
ffmpeg -framerate 15 -i build/previews/photo-reveal/frames/%04d.png -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,fps=30" -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart build/previews/photo-reveal/demo.mp4
```

For website screenshots, run `flutter test tool/preview_website_test.dart`, then the site's
`scripts/export-app-screenshots.mjs` converter. Keep profiles and conversations fictional and labelled.

## Builds and release preparation

```bash
flutter build apk --debug
```

This checks an Android development artifact, not store readiness. The checked-in Android release
build currently uses debug signing; configure production signing before distributing a release.
Keep signing credentials outside the public environment asset.

Also verify the optimized Android build after changes to native dependencies or build settings:

```bash
flutter build apk --release
```

Install it over the existing app without clearing data, launch it from a stopped process, and
check that it stays open and resumes correctly. A successful build or debug launch does not
verify release startup. Flutter loads `android/app/proguard-rules.pro` automatically; its targeted
Room constructor rule prevents WorkManager initialization from failing before Flutter starts
when R8 removes the reflectively created database constructor.

iOS builds require macOS, Xcode and the intended signing/provisioning setup. Validate native
permissions, Keychain, sharing, APNs, launch assets and store purchases on representative devices.
Do not infer iOS success from Android or widget tests.

The phone interface is locked to portrait-up at Flutter startup and in the Android manifest and
both iOS property lists. Rebuild and restart after changing native settings, then rotate the device
on the feed and a form: the interface and drafts must stay in place. iPad full-screen mode is
required for its orientation restriction. Android 16+ may override orientation locks on displays
at least 600 dp wide; see [Flutter's platform limits](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html).

For screen privacy, test Recents/app-switcher previews from a conversation, photo and OTP form,
including rotation, interruptions and returning from a system dialog. Drafts must remain intact.
On Android, system screenshots should be rejected or blank and recordings must not show app
content. Test at least API 24 and API 33+ after a full native rebuild. On iOS, verify app-switcher
masking and active recording/mirroring on iOS 15–17 and iOS 18+. A still screenshot while the app
is active remains possible on iOS; there is no supported global screenshot-blocking API. Avoid
secure-text-field view-hierarchy workarounds. Native shields do not protect other applications,
an external camera or a compromised OS.

On Android, disable device location, request a position from the feed and accept the native
activation prompt: the same request should then obtain one fresh fix. Declining must show
feedback in the location card and send no position. Check permission denial, cancellation,
and the settings fallback on devices where native activation is unavailable. On iOS, disabled
services retain a settings action. Mocked provider tests do not verify the real system dialog.

Before beta, record the app/API versions, environment, tested flows and outstanding issues.
Provider enablement and local compilation are separate from approval and availability in the stores.
