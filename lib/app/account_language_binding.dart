import 'dart:async';

import '../core/l10n/api_language.dart';
import '../core/l10n/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/api_failure.dart';
import '../features/auth/domain/authenticated_session.dart';
import '../features/language/data/language_repository.dart';

/// Bridges a device UI preference to a verified account without owning auth.
/// Writes are explicit selections only; restoration never overwrites an account.
class AccountLanguageBinding {
  AccountLanguageBinding(this.locale, this.session)
    : repository = LanguageRepository(session) {
    session.addListener(_changed);
    _changed();
  }
  final LocaleController locale;
  final AuthenticatedSession session;
  final LanguageRepository repository;
  RequestCancellation _scope = RequestCancellation();
  String? _owner;
  int _epoch = 0;
  bool _disposed = false;
  ApiFailure? _failure;

  void _changed() {
    if (_disposed) return;
    final next = session.hasSession ? session.identity?.userId : null;
    if (next == _owner) return;
    _owner = next;
    _failure = null;
    _epoch++;
    _scope.cancel();
    _scope = RequestCancellation();
    locale.onSelected = null;
    if (next == null) {
      locale.useAccountLanguage(null);
      return;
    }
    final epoch = _epoch;
    final scope = _scope;
    locale.onSelected = (language) => _write(language, next, epoch, scope);
    unawaited(_read(next, epoch, scope));
  }

  bool _alive(String owner, int epoch) => !_disposed && epoch == _epoch &&
      session.hasSession && session.identity?.userId == owner;

  Future<void> _read(String owner, int epoch, RequestCancellation scope) async {
    try {
      final language = await repository.read(scope);
      if (_alive(owner, epoch)) locale.useAccountLanguage(language);
    } catch (error) {
      if (_alive(owner, epoch)) {
        if (error is ApiFailure) _failure = error;
        if (!locale.hasPreference) locale.accountSyncFailed();
      }
    }
  }

  Future<void> _write(ApiLanguage language, String owner, int epoch,
      RequestCancellation scope) async {
    // Selection may have awaited secure storage while the account was closing.
    if (!_alive(owner, epoch)) return;
    final previous = _failure;
    if (previous != null && previous.retryAt?.isAfter(DateTime.now()) == true) {
      throw previous;
    }
    try {
      await repository.write(language, scope);
      if (_alive(owner, epoch)) _failure = null;
    } on ApiFailure catch (error) {
      if (_alive(owner, epoch)) _failure = error;
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _scope.cancel();
    locale.onSelected = null;
    session.removeListener(_changed);
  }
}
