# Session recovery

[Documentation](../README.md#documentation)

`JWT_REFRESH_TTL` belongs to the API and slides only after successful rotation. The app has no
inactivity logout timer or scheduled background refresh.

## Rotation protocol

Before `POST /api/auth/refresh`, `SessionController` durably stores the original credential and
UUIDv4. Send the UUID in both `Idempotency-Key` and `recovery_id`, without an access bearer.
Concurrent callers share the operation.

Network/timeouts, rate limits and server errors retain the attempt and temporarily hide private
UI. Retry, foreground return and process restart reuse the exact credential/key, respecting
cooldowns. No timer repeatedly retries failure. Save the replacement pair before exposing access;
a storage failure retains the original sealed attempt.

The API can recover the committed replacement for seven days while its token/session stay active.
Recovery creates no second child and extends neither the receipt nor session expiry. A different
attempt on an old token still triggers replay protection. Revoked/expired families or receipts and
already-rotated replacements cannot recover. Definitive `401`, unavailable account or logout clears
recovery data. Legacy `rotating` records without a recovery key require sign-in.

## Rollout and checks

Apply the schema migration, deploy API and maintenance worker, then distribute the app. Older APIs
reject the new body field before consuming the token, leaving the attempt resumable. Older clients
retain strict rotation; already-deleted credentials cannot be restored. No new environment fields.

```bash
flutter test test/session_test.dart test/auth_widget_test.dart test/cache_lifecycle_regressions_test.dart test/notifications_test.dart
flutter analyze
```

Use synthetic credentials; never log tokens, attempt IDs or bodies. Server checks:
[refresh recovery](../../histae-api-rust/docs/refresh-recovery.md).
