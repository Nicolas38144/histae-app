# Store update gate

[Documentation](../README.md#documentation)

Release builds check the stores at startup, on foreground return and every 15 minutes while
active. Confirmed availability covers the entire navigator with an update action. The underlying
routes and drafts stay mounted. Store lookup errors do not create a block; an already confirmed
block remains until a successful check says it no longer applies. Nothing is persisted.

No additional service, registration, API route, secret or environment field is required.
Package and bundle identifiers come from the installed application.

## Platform checks

- **Android:** the native Play In-App Update library checks the installed package's release
  track, account and device. Both an available update and an update already in progress are
  recognized only when the available version code is higher. Debug and non-Play installations
  are excluded. The action opens Google Play, with its HTTPS listing as a fallback.
- **iOS:** production App Store receipts are required. TestFlight, simulators and debug builds
  are excluded. StoreKit supplies the current account's storefront, not the device language or
  location. A factual ISO-country table converts its alpha-3 country code to Apple's alpha-2
  lookup parameter. The public result must match the exact bundle, have a newer numeric version
  and require no newer iOS version than the device has. Unknown storefronts, missing listings
  and malformed metadata do not create a block. The action opens the regional App Store listing.

The country table contains ISO identifiers from system `RegionInfo` metadata; it is not user data.
Public store metadata requests carry no Histae authentication or account identifiers.

The gate is enforced by versions containing this implementation. Previously distributed builds
cannot acquire it retroactively. It does not establish an API-side minimum version policy.

## Verification

```bash
flutter test test/store_updates_test.dart
flutter build apk --release
```

For a real Android check, install an older **release build containing the gate from Google Play**,
then publish a higher version code to a track accessible to that same account/device. Confirm
blocking, the store action, foreground rechecks, unavailable tracks and an unreachable store.
Do not expect an emulator or a manually installed APK to prove Play availability.

iOS native compilation requires macOS/Xcode. Validate the receipt/storefront bridge on an App
Store installation, unavailable countries, incompatible iOS versions and store return. TestFlight
alone cannot verify production blocking. A successful Android build does not verify iOS.

Official behavior: [Play availability checks](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java),
[StoreKit storefront](https://developer.apple.com/documentation/storekit/storefront),
[Apple lookup](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/),
[Apple phased release and manual availability](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases).
