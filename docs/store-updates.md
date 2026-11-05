# Store update gate

[Documentation](../README.md#documentation)

Release builds check at startup, foreground return and every 15 active minutes. Confirmed update
availability covers navigation with a store action while keeping routes/drafts mounted. Errors
do not create a block; a confirmed block remains until a successful check clears it. State is
not persisted. No extra service, registration, API route or environment field is needed.

## Availability

- **Android:** Play In-App Update checks the installed package, account, track and device for a
  higher version code, including an update in progress. Debug/non-Play installs are excluded.
  The action opens Play, with an HTTPS listing fallback.
- **iOS:** requires a production receipt; excludes debug, simulator and TestFlight. StoreKit's
  account storefront determines the lookup country via the ISO mapping. The result must match
  the bundle, have a newer numeric version and support the installed iOS version. Missing/invalid
  metadata or unknown storefronts do not block. The action opens the regional listing.

Public metadata carries no Histae credentials. Only builds containing this gate enforce it;
it does not establish an API minimum-version policy or affect earlier apps retroactively.

## Verification

```bash
flutter test test/store_updates_test.dart
flutter build apk --release
```

Install an older release containing the gate from Play, then make a newer code accessible to the
same account/device. Check blocking, store return/rechecks, inaccessible tracks and network failure.
A sideloaded APK does not prove Play availability. On macOS/iOS, validate the production receipt,
storefront, unavailable countries and incompatible OS versions; TestFlight alone is insufficient.

References: [Play updates](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java),
[StoreKit storefront](https://developer.apple.com/documentation/storekit/storefront),
[Apple lookup](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/).
