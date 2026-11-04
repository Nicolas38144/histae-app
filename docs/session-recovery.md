# Session recovery

[Documentation](../README.md#documentation)

A sliding refresh-token lifetime only advances on a successful rotation. Inactivity does not
schedule background refreshes. The API's `JWT_REFRESH_TTL` remains the source of that lifetime;
the application has no separate inactivity logout timer.

## Pending rotation

Before `POST /api/auth/refresh`, `SessionController` atomically persists the original credential
and a random UUIDv4 in the device's secure vault. The UUID is sent in both `Idempotency-Key` and
`recovery_id`; the request has no access bearer. All simultaneous rotations share one operation.

Network failures, timeouts, rate limits and server errors keep this attempt. The UI becomes
temporarily unavailable and Retry uses exactly the same credential and key. Returning to the
foreground also resumes an unresolved attempt, subject to the current server cooldown. A process
restart reads the same sealed attempt. There is no timer repeatedly retrying a failed refresh.

The API can recover its committed replacement for seven days, while the replacement token and
session are active. It reissues an access token but neither creates a second refresh child nor
extends the original recovery deadline or sliding session expiry. An authentic old token with
a different attempt still triggers replay protection. Revoked/expired families, expired recovery
receipts and already-rotated replacements are not recoverable.

The new pair is persisted before the access token can reach a resource request. A storage failure
after the server response keeps the original sealed attempt, so saving can be retried safely.
A definitive `401` or unavailable account signs out and removes recovery material. An explicit
logout clears it too. Legacy `rotating` records have no recovery key and still require sign-in.

## Delivery

Apply the API schema migration, deploy the API and maintenance worker, then distribute the app.
The optional body field is deliberately rejected by an older API before it consumes the refresh
token; the app keeps the attempt until the compatible API becomes available. Older applications
continue to use strict, non-recoverable rotation against the new API. A deployment cannot restore
credentials that an earlier app has already deleted. No new environment variables are needed.

## Verification

```bash
flutter test test/session_test.dart test/auth_widget_test.dart test/cache_lifecycle_regressions_test.dart test/notifications_test.dart
flutter analyze
```

Test with synthetic credentials. Never log refresh tokens, attempt IDs or request bodies. API
verification instructions belong to `histae-api-rust/docs/refresh-recovery.md`.
