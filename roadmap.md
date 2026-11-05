# Release validation

[Documentation](README.md#documentation) · [Product flows](resume.md)

Core account, profile, discovery, messaging, reveal, credits, privacy, push and purchase flows are
implemented. Track deployed API capability and real device/provider validation separately.

## Remaining checks

| Area | Verify before release |
| --- | --- |
| Android | Signed Play delivery, versioning, optimized cold start, upgrades without clearing data |
| iOS | macOS build/signing, Keychain, launch, permissions, sharing and portrait behavior |
| Authentication | Real OTP, refresh recovery, process interruption and account switching |
| Discovery/photos | Capture/upload, pause, expired presence, photo replacement and withdrawal |
| Conversations | Two-account delivery/receipts, continuation deadlines, archives and deletion |
| Push | API/worker credentials, APNs, permission, background and cold-start delivery |
| Rewards | Published UMP message, test devices, ads, signed callback and quota refresh |
| Purchases/updates | Test products, verification, completion, restore, delayed events and actual store availability |
| Accessibility | Long text, four locales, 200% text, keyboard, small screens and native icon masks |
| Privacy | Documents, provider disclosures, support and temporary-file cleanup |

Record environment, app/API versions, result and outstanding issues. Include loading, empty,
failure, uncertain-result and access-loss cases according to risk. Mock tests and local builds
cannot validate a provider or another platform.

## Known dependencies

The consent precheck cannot guarantee atomic acceptance during document publication: the API
needs an expected-version precondition. Check deployed contract/schema, private storage, outbox,
maintenance and enabled providers before relying on a client feature. Deploy refresh recovery in
the order described in [Session recovery](docs/session-recovery.md).

Website Stripe validation belongs to the web release; mobile purchases use stores. See the
[API billing guide](../histae-api-rust/docs/store-billing.md), [Configuration](docs/configuration.md)
and [Development](docs/development.md) for setup and commands. Keep this backlog focused on
remaining work rather than completed task history.
