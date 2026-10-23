# API request languages

[Documentation](../README.md#documentation) · [Interface localization](../lib/core/l10n/README.md)

Supported wire codes are `fr`, `en`, `es` and `it`. JSON, multipart, export and SSE requests use
the language resolved by `LocaleController` in `Accept-Language`. Business payload contracts remain
unchanged.

## Account and device preference

French is the initial fallback. A saved device preference, including system mode, takes precedence.
Without a local choice, `AccountLanguageBinding` reads `GET /api/users/me/language` to adopt the
verified account's language. This read does not write a preference.

An explicit signed-in choice updates the interface and calls `PATCH /api/users/me/language`, for
example with `{ "language": "it" }`. A failed account update leaves the interface usable, reports
the failure and respects `Retry-After` before another deliberate attempt. App restoration and
system-language changes do not silently overwrite the account preference.

Logout removes the account fallback but preserves an explicit device choice. Unsupported languages
fall back to French.

## Flow-specific rules

| Flow | Rule |
| --- | --- |
| Catalogue, profile, traits, questions, feed and matches | Localized reads; ignore old revisions and restart pagination when needed |
| Consent | Check the shown version, URL and `document_language`; retain `accepted_document_language` as historical evidence |
| OTP | Freeze language with the phone/idempotency key; a deliberate resend starts a new intention |
| Native purchases | API intentions/verification use request language; store SDKs provide localized prices |
| Subscription management | Open the original store; existing Stripe subscriptions are website-managed |
| Push devices | Device language override follows registration; `null` follows the account |
| Export and SSE | Send language at opening; preserve protocol keys and personal content |

Personal biographies, answers and messages are never translated by the client. Signed photos use
a separate transport without Bearer credentials. Native dialogs follow their own platform settings.

## Request consistency

Localization revision is separate from `resourceKey`. A language change renews affected reads
without clearing navigation, drafts or immutable write intentions. Cached data from another
language is not reused.

A permitted retry after confirmed token expiry retains the original request language. A timeout
does not automatically repeat a mutation. In-flight push registration keeps its parameters until
resolved, and language changes do not reset a native purchase or its verification.

Unconfirmed consent choices are invalidated when the shown document changes, even at the same legal
version. Changing language is not consent. An unavailable document read does not simulate logout;
authentication rejection still follows the normal session protections.

## Native billing and the website

The shared language-aware transport covers store product discovery, purchase intentions,
Apple/Google verification and subscription reads. Store account settings determine displayed prices
independently of API language. Restoration verifies with the server and cannot reassign ownership.

Old mobile Stripe Checkout/portal routes return `410 billing_web_only`. Website UUID/phone/OTP
authentication uses its own cookie and does not reuse mobile credentials. Its localization and
retry rules belong to the [server billing guide](../../histae-api-rust/docs/store-billing.md).

## Verification

```bash
flutter test test/api_language_test.dart test/localization_test.dart
```

Add existing OTP, session, billing or notification suites only when affected. Simulations require
no real SMS, payment or push. On devices, verify pre-login selection, system mode, legal documents,
purchase restoration and an already-enabled push device's language. Common commands and release
criteria are in [Development](development.md) and the [roadmap](../roadmap.md).
