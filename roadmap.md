# Release validation

[Documentation](README.md#documentation) · [Product flows](resume.md)

Core account, profile, discovery, messaging, reveal, credits, privacy, push and purchase flows are
implemented. Track deployed API capability and real device/provider validation separately.

## Confirmed on Android

The owner confirmed these areas on their phone on 2026-11-05. Validation applies to the tested
Android build and environment; iOS remains pending.

- [x] Android
- [x] Authentication
- [x] Discovery/photos
- [x] Conversations
- [x] Push
- [x] Rewards
- [x] Purchases/updates
- [x] Accessibility

## Remaining checks

| Area | Verify before release |
| --- | --- |
| iOS | macOS build/signing, Keychain, launch, permissions, sharing, portrait and enabled providers |
| Privacy | Complete the checks below using test accounts |
| New push events | API checks and real-device delivery of the six new events, names and private destinations |
| Notification choices | Deploy the matching API migration/worker; verify six categories, private mutes/expiry, cross-device choices, discreet display and Android channel settings on devices |
| Message recovery | Simulations cover lost responses, process restart, reconnect and stable composer; verify real Wi-Fi/mobile switching, airplane mode and OS termination during send on devices |

Record environment, app/API versions, result and outstanding issues. Include loading, empty,
failure, uncertain-result and access-loss cases according to risk. Mock tests and local builds
cannot validate a provider or another platform.

### Privacy

- [ ] Open current documents in all four languages; verify dates, contact, retention and provider
  disclosures against actual behavior and the Play Data safety declaration.
- [ ] Withdraw sensitive-data, location and advertising choices; verify the affected use stops
  without resetting the choice after relaunch. OS permission alone is not consent.
- [ ] Withdraw photo sharing from one account and check both participants, cached views and restart.
- [ ] Revoke another session, disable notifications and block a test account; verify access and
  delivery stop as expected. Check account switching leaves no previous private data/drafts.
- [ ] Export test data and check its contents; verify app-owned temporary files are removed after
  sharing/leaving. Copies deliberately saved elsewhere remain outside app cleanup.
- [ ] Submit a correction request, process it in the dashboard and read the reply in the app.
- [ ] Delete a test account; verify access closes immediately and server-side cleanup completes.
  Check the public web deletion path and support contact without requiring the installed app.

References: [CNIL permissions and consent](https://www.cnil.fr/fr/permissions-applications-mobiles-recommandations-de-la-cnil-pour-respecter-la-vie-privee),
[Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

## Known dependencies

The consent precheck cannot guarantee atomic acceptance during document publication: the API
needs an expected-version precondition. Check deployed contract/schema, private storage, outbox,
maintenance and enabled providers before relying on a client feature. Deploy refresh recovery in
the order described in [Session recovery](docs/session-recovery.md).

Website Stripe validation belongs to the web release; mobile purchases use stores. See the
[API billing guide](../histae-api-rust/docs/store-billing.md), [Configuration](docs/configuration.md)
and [Development](docs/development.md) for setup and commands. Keep this backlog focused on
remaining work rather than completed task history.
