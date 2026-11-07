# Public client configuration

[Documentation](../README.md#documentation)

The ignored root `.env` is bundled as a public asset. Supply it before local/CI builds and rebuild
or restart after changes. Never put Stripe secrets, Firebase private keys or signing credentials
here. No environment example file is maintained.

## API origin

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

`APP_ENV`: `development`, `staging` or `production`. The URL must be an origin without `/api`,
credentials, query or fragment; repositories add paths. Local Android emulator:
`APP_ENV=development`, `API_BASE_URL=http://10.0.2.2:8080`. A phone needs a reachable LAN address.
HTTP is allowed only in debug/development; other builds require HTTPS. Invalid configuration
shows an unavailable-service screen without a fallback host.

## Support contact

```dotenv
SUPPORT_EMAIL=support.histae@gmail.com
SUPPORT_WEBSITE_URL=https://www.histae.com
```

Email opens the user's mail app without sending automatically; an empty value shows the localized
coming-soon fallback. The optional HTTPS website origin enables the localized child-safety link.
In-app safety instructions remain available without it.

## Optional providers

Keep services disabled until native and API setup is ready. Booleans are `true`/`false`.

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

### Rewarded videos

AdMob app IDs contain `~`; rewarded-unit IDs contain `/`. Native build setup reads app IDs from
this asset. Playback also requires eligibility, published UMP configuration and an API reward
intent, which supplies the authoritative unit/custom data. SDK completion alone grants no credit;
validate test-device delivery and the signed server reward callback.

### Push notifications

Copy public Firebase options from the registered Android/iOS apps, using actual identifiers rather
than project display names. Dart uses explicit `FirebaseOptions`; Android also generates native
resources for cold-start delivery. Set `PUSH_ENABLED=true` only with complete target-platform options.

After verified account setup the app requests native permission/registers first use. Refusal,
manual opt-out and remotely removed devices are not automatically reversed. Device settings remain
accessible while push is disabled. OS alerts are background-only; open-app messages use realtime
state. Notification taps open authorized destinations.

Six account-wide categories, discreet display and private conversation mutes use the API's
notification-preference routes. They require the matching API migration/worker, with no new `.env`
values. Existing device opt-outs remain unchanged. Opening a settings editor reads current choices;
ordinary tab navigation does not. Android channel names come from the ARBs via
`dart run tool/generate_native_localizations.dart` and preserve system sound/importance choices.

API/worker sending credentials are separate. iOS also requires APNs, capabilities and signing
validation on macOS. Public configuration alone does not prove delivery.

### Purchases

Google Play/StoreKit provide products/prices; identifiers come from the API catalogue. The API
verifies ownership before completion, and restoration cannot transfer a purchase between accounts.
Enable `BILLING_ENABLED=true` after product and Sandbox/Play test validation. The client presents
no trial/introductory offer. Stripe subscriptions are website-managed; mobile Stripe Checkout and
old distribution/return-URL settings are unsupported.

Provider setup: [server billing guide](../../histae-api-rust/docs/store-billing.md).
