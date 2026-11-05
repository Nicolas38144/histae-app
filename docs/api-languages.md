# API request languages

[Documentation](../README.md#documentation) · [Interface localization](../lib/core/l10n/README.md)

`LocaleController` supplies `fr`, `en`, `es` or `it` through `Accept-Language` for JSON, multipart,
export and SSE. Personal biographies, answers and messages are never translated.

## Preference resolution

Saved device preference, including system mode, wins. Without one, `AccountLanguageBinding` reads
`GET /api/users/me/language` and adopts the verified account's language without writing it.
French is the fallback. Logout clears account fallback while preserving explicit device choice.

An explicit signed-in selection updates the UI and calls `PATCH /api/users/me/language`.
Failure keeps the UI usable, reports the failure and respects `Retry-After`. Restore/system changes
do not silently overwrite the account preference.

## Consistency rules

- Language revisions invalidate localized reads/pagination, without clearing navigation, drafts or
  immutable write intentions. Do not reuse another language's snapshots.
- OTP freezes language with phone/key. Permitted auth retries retain original request language;
  timeouts do not automatically repeat mutations. Pending push/purchase intentions retain parameters.
- Consent compares version, URL and `document_language`; `accepted_document_language` is historical
  evidence. Changed documents invalidate unsaved choices, even at the same version. Language changes
  never constitute consent; failed document reads do not simulate logout.
- Store SDKs localize prices independently; API purchase verification still uses request language.
  Existing Stripe subscriptions remain website-managed.
- Push device override uses its selected language; `null` follows the account. Export/SSE retain
  protocol keys and personal text. Signed photos use separate transport without Bearer credentials;
  native dialogs follow platform settings.

## Verification

```bash
flutter test test/api_language_test.dart test/localization_test.dart
```

Add affected OTP/billing/notification suites only as needed. On devices check pre-login choice,
system mode, legal documents, restoration and enabled push-language changes.
