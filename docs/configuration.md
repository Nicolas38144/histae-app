# Public client configuration

[Documentation](../README.md#documentation)

The root `.env` is ignored by source tracking but bundled as a Flutter asset. Supply it before a
local or CI build, then rebuild/restart after changes. It is public configuration, not secret
storage. Stripe secrets, Firebase private keys and service-account credentials belong to the API.
No `.env.example` file is maintained.

## API origin

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

`APP_ENV` accepts `development`, `staging` or `production`. `API_BASE_URL` is an origin with no
`/api` path, credentials, query or fragment. Repositories supply their full `/api/...` paths.

For a local API on the standard Android emulator, use `APP_ENV=development` and
`API_BASE_URL=http://10.0.2.2:8080`. A physical phone needs a reachable LAN address.
HTTP is accepted only for a debug build in development; other configurations require HTTPS.
Invalid or missing configuration shows the unavailable-service flow rather than a fallback host.

## Support contact

```dotenv
SUPPORT_EMAIL=support.histae@gmail.com
SUPPORT_WEBSITE_URL=https://www.histae.com
```

This public address appears in Help and contact and enables a button that opens the person's
email app; nothing is sent automatically. An empty field shows the localized “Email address
coming soon” fallback. No support backend or API change is required. Rebuild after changing the asset.

`SUPPORT_WEBSITE_URL` is an optional HTTPS origin. It enables the localized public child-safety
standards link in Help and contact. Safety reporting instructions remain available in the app
even without that origin. It is public configuration, not a credential.

## Optional provider fields

Leave optional services disabled until their platform and API configuration is ready:

```dotenv
ADMOB_ANDROID_APP_ID=
ADMOB_IOS_APP_ID=
ADMOB_ANDROID_REWARDED_AD_UNIT=
ADMOB_IOS_REWARDED_AD_UNIT=

PUSH_ENABLED=false
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_ANDROID_API_KEY=
FIREBASE_ANDROID_APP_ID=
FIREBASE_IOS_API_KEY=
FIREBASE_IOS_APP_ID=
FIREBASE_IOS_BUNDLE_ID=

BILLING_ENABLED=false
```

Use the boolean literals `true` and `false`. Populate identifiers from the appropriate provider
project and platform app; do not substitute the project display name for a required identifier.

## Rewarded videos

AdMob application IDs contain `~`; rewarded ad-unit IDs contain `/`. Native Android/iOS setup also
needs the application ID. Android build configuration and the iOS AdMob build phase read it from
the public environment.

Playback requires an eligible account, working UMP configuration and the API's reward intent.
The API intent selects the authoritative ad unit and custom data. The SDK completion callback
does not grant a credit: the server must validate the reward. Verify the UMP message, test device,
ad delivery and signed server callback in the intended provider environment before release.

## Push notifications

Use the public Firebase options for each registered Android/iOS app. The Dart gateway initializes
Firebase with explicit `FirebaseOptions`; Android additionally builds native Firebase resources
from the same public fields for cold-start delivery.

Set `PUSH_ENABLED=true` only with a complete configuration for the target platform. The user must
still enable notifications, grant native permission and register the device with the API.
The device-management screen remains available when push is disabled.

Provider sending credentials are configured separately on the API and worker. iOS also needs its
APNs, signing and native capabilities checked on macOS. Public options alone do not prove delivery.

## Purchases and subscription management

Android uses Google Play Billing; iOS uses StoreKit. Product identifiers come from the API's store
catalogue; display prices come from the platform SDK. The API verifies purchases before the app
finishes them, and restoration never transfers a purchase to a different Histae account.

Enable `BILLING_ENABLED=true` after configuring store products and validating Sandbox/Play test
flows. No new trial or introductory offer is presented by the client. Existing Stripe subscriptions
remain visible as website-managed subscriptions; Stripe Checkout is not offered inside the app.
Old mobile Stripe distribution and return-URL fields are no longer supported configuration.

For provider credentials, notifications, products and API activation, use the server's
[store and website billing guide](../../histae-api-rust/docs/store-billing.md).
