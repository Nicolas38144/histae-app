import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/retry_after.dart';
import '../../consents/domain/consent_state.dart';
import '../data/auth_repository.dart';
import '../data/session_vault.dart';
import '../domain/authenticated_session.dart';

export '../domain/authenticated_session.dart' show SessionPhase;

class SessionController extends ChangeNotifier implements AuthenticatedSession {
  SessionController(this.repository, this._vault, {Listenable? languageChanges})
    : _languageChanges = languageChanges {
    _lastLanguage = language;
    languageChanges?.addListener(_languageChanged);
  }
  final Listenable? _languageChanges;
  late ApiLanguage _lastLanguage;
  int _localizationRevision = 0;
  @override
  int get localizationRevision => _localizationRevision;
  @override
  ApiLanguage get language => repository.api.language;

  void _languageChanged() {
    if (_disposed || _lastLanguage == language) return;
    _lastLanguage = language;
    _localizationRevision++;
    // Separate from privacy/resource revisions: never discard drafts or intents.
    _notify();
    unawaited(_reloadLanguage());
  }

  Future<void> _reloadLanguage() async {
    await _sync;
    if (_disposed || !hasSession || retrySeconds > 0) return;
    if (identity == null) {
      await synchronize();
      return;
    }
    final generation = _generation, revision = localizationRevision;
    final requestLanguage = language;
    _localizedReads++;
    _notify();
    try {
      final state = ConsentState.fromJson(
        await _authorized(
          'GET',
          '/api/users/me/consents',
          language: requestLanguage,
        ),
      );
      if (_disposed ||
          generation != _generation ||
          revision != localizationRevision) {
        return;
      }
      _acceptConsents(state);
      _applyConsentPhase(state);
    } on ApiFailure catch (error) {
      if (!_disposed &&
          hasSession &&
          generation == _generation &&
          revision == localizationRevision) {
        // A failed translation read must not replace the session/navigation.
        // Definitive auth rejection is still handled by _authorized.
        _setFailure(error);
      }
    } finally {
      _localizedReads--;
      _notify();
    }
  }

  final AuthRepository repository;
  final SessionVault _vault;
  @override
  SessionPhase phase = SessionPhase.restoring;
  @override
  MobileIdentity? identity;
  @override
  ConsentState? consents;
  ApiFailure? failure;
  String? notice;
  TokenPair? _tokens;
  RequestCancellation _scope = RequestCancellation();
  Future<void>? _start;
  Future<void>? _sync;
  Future<void>? _rotation;
  Future<void>? _logout;
  Future<void>? _terminal;
  int _generation = 0;
  int resourceRevision = 0;

  @override
  String get resourceKey => '$_generation:$resourceRevision';
  String? _consentFingerprint;
  bool _disposed = false;
  bool _loggingOut = false;
  bool _establishing = false;
  bool _saving = false;

  bool get isSaving => _saving;
  bool _synchronizing = false;
  int _localizedReads = 0;

  @override
  bool get isSynchronizing => _synchronizing || _localizedReads > 0;
  late final RetryTicker _retryTimer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );

  @override
  int get retrySeconds => retrySecondsUntil(failure?.retryAt);

  void _setFailure(ApiFailure error) {
    failure = error;
    _retryTimer.cancel();
    if (retrySeconds > 0) {
      _retryTimer.restart();
    }
  }

  @override
  Uri get apiOrigin => repository.api.origin;

  String get _origin => apiOrigin.toString();

  @override
  Future<Object?> publicJson(
    String path, {
    RequestCancellation? cancellation,
  }) => repository.api.getJson(path, cancellation: cancellation);

  @override
  bool get hasSession => _tokens != null && !_loggingOut;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _write(String phase, [String? refresh]) async {
    try {
      await _vault.write(SessionRecord(_origin, phase, refresh).encode());
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }

  Future<void> start() => _start ??= _restore();

  Future<void> _restore() async {
    try {
      final record = SessionRecord.decode(await _vault.read());
      if (_disposed) return;
      if (record == null || record.phase == 'signed_out') {
        phase = SessionPhase.signedOut;
      } else if (record.origin == _origin && record.phase == 'closing') {
        await _invalidate(const ApiFailure(ApiFailureKind.sessionUncertain));
        notice = 'closure_unconfirmed';
      } else if (record.origin != _origin || record.phase != 'ready') {
        await _invalidate(const ApiFailure(ApiFailureKind.sessionUncertain));
      } else {
        await _rotate(record.refreshToken!);
        if (hasSession) await synchronize();
      }
    } on ApiFailure catch (error) {
      if (error.kind == ApiFailureKind.secureStorage) {
        phase = SessionPhase.storageFailure;
        failure = error;
      } else if (phase != SessionPhase.signedOut &&
          phase != SessionPhase.storageFailure) {
        await _invalidate(error);
      }
    } catch (_) {
      phase = SessionPhase.storageFailure;
      failure = const ApiFailure(ApiFailureKind.secureStorage);
    }
    _notify();
  }

  Future<void> establish(TokenPair tokens) async {
    if (_disposed || _establishing || _loggingOut || hasSession) return;
    _establishing = true;
    failure = null;
    notice = null;
    try {
      await _write('ready', tokens.refreshToken);
      if (_disposed) return;
      _generation++;
      _scope.cancel();
      _scope = RequestCancellation();
      _tokens = tokens;
      await synchronize();
    } on ApiFailure catch (error) {
      // Do not publish credentials if their secure persistence failed.
      try {
        await repository.logout(tokens);
      } on ApiFailure {
        /* Best effort. */
      }
      await _invalidate(error);
    } finally {
      _establishing = false;
    }
  }

  Future<void> _rotate(String refresh) {
    if (_rotation case final pending?) return pending;
    final task = _performRotation(refresh);
    _rotation = task;
    return task.whenComplete(() {
      if (identical(_rotation, task)) _rotation = null;
    });
  }

  Future<void> _performRotation(String refresh) async {
    try {
      // Must finish BEFORE sending. If this write fails, do not call refresh.
      await _write('rotating');
      final next = await repository.refresh(refresh);
      await _write('ready', next.refreshToken);
      _tokens = next; // Publish access only after the replacement is durable.
    } on ApiFailure catch (error) {
      await _invalidate(
        error.kind == ApiFailureKind.secureStorage
            ? error
            : const ApiFailure(ApiFailureKind.sessionUncertain),
      );
      rethrow;
    }
  }
  // Repositories opt in only after a definitive expired-access 401. Never
  // replay a mutation after a timeout or a lost response.
  // A revoked session (authentication_required) is closed, never refreshed.

  Future<Object?> _authorized(
    String method,
    String path, {
    Object? body,
    ApiLanguage? language,
    bool events = false,
    bool download = false,
    Map<String, String>? query,
    List<int>? photo,
    String? idempotencyKey,
    int expectedStatus = 200,
    bool replayAfterRefresh = true,
    RequestCancellation? cancellation,
  }) async {
    final generation = _generation;
    final requestLanguage = language ?? this.language;
    if (_rotation case final pending?) await pending;
    final used = _tokens;
    if (used == null || _loggingOut || _disposed || generation != _generation) {
      throw const ApiFailure(ApiFailureKind.unauthenticated);
    }
    final scope = _scope;
    final combined = RequestCancellation();
    unawaited(
      Future.any([
        scope.whenCancelled,
        if (cancellation != null) cancellation.whenCancelled,
      ]).then((_) => combined.cancel()),
    );
    Future<Object?> send(TokenPair tokens) async {
      if (scope.isCancelled || (cancellation?.isCancelled ?? false)) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      final result = download
          ? await repository.api.openDataExport(
              bearer: tokens.accessToken,
              cancellation: combined,
            )
          : events
          ? await repository.api.openEvents(
              bearer: tokens.accessToken,
              cancellation: combined,
            )
          : await repository.api.requestJson(
              method,
              path,
              body: body,
              language: requestLanguage,
              query: query,
              photo: photo,
              idempotencyKey: idempotencyKey,
              bearer: tokens.accessToken,
              cancellation: combined,
              expectedStatus: expectedStatus,
            );
      if (generation != _generation || _loggingOut || _disposed) {
        if (result is ApiEventStream) result.close();
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      return result;
    }

    try {
      return await send(used);
    } on ApiFailure catch (error) {
      if (_disposed || _loggingOut || generation != _generation) rethrow;
      if (error.statusCode == 401 &&
          error.code == 'invalid_or_expired_access_token' &&
          replayAfterRefresh) {
        if (_tokens?.accessToken == used.accessToken) {
          await _rotate(used.refreshToken);
        }
        if (_tokens == null || _loggingOut || generation != _generation) {
          rethrow;
        }
        try {
          return await send(_tokens!);
        } on ApiFailure catch (again) {
          if (again.statusCode == 401 || again.code == 'account_unavailable') {
            await _invalidate(again);
          }
          rethrow;
        }
      }
      if (error.statusCode == 401 || error.code == 'account_unavailable') {
        await _invalidate(error);
      }
      rethrow;
    }
  }

  @override
  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    ApiLanguage? language,
    Map<String, String>? query,
    List<int>? photo,
    String? idempotencyKey,
    required int expectedStatus,
    required bool replayAfterRefresh,
    RequestCancellation? cancellation,
  }) {
    return _authorized(
      method,
      path,
      body: body,
      language: language,
      query: query,
      photo: photo,
      idempotencyKey: idempotencyKey,
      expectedStatus: expectedStatus,
      replayAfterRefresh: replayAfterRefresh,
      cancellation: cancellation,
    );
  }

  @override
  Future<ApiEventStream> openEvents(RequestCancellation cancellation) async =>
      await _authorized(
        'GET',
        '/api/users/me/events',
        events: true,
        cancellation: cancellation,
      ) as ApiEventStream;

  @override
  Future<ApiDownload> openDataExport(RequestCancellation cancellation) async =>
      await _authorized(
        'GET',
        '/api/users/me/data-export',
        download: true,
        cancellation: cancellation,
      ) as ApiDownload;
  // These operations revoke this very session. First remove the reusable
  // refresh from durable storage, then cross the barrier that purges all UI.
  // The single request uses the latest access token, with no replay/rotation
  // after the barrier. A lost response never becomes an authentication probe.

  @override
  Future<void> eraseAccount(String confirmationToken) =>
      _closeRemote('erasure', confirmationToken: confirmationToken);

  @override
  Future<void> logoutEverywhere() => _closeRemote('all');

  @override
  Future<void> revokeCurrentSession(String id) =>
      _closeRemote('current', sessionId: id);

  Future<void> _closeRemote(
    String action, {
    String? confirmationToken,
    String? sessionId,
  }) {
    if (_terminal case final pending?) return pending;
    final task = _performRemoteClosure(
      action,
      confirmationToken: confirmationToken,
      sessionId: sessionId,
    );
    _terminal = task;
    return task.whenComplete(() {
      if (identical(_terminal, task)) _terminal = null;
    });
  }

  Future<void> _performRemoteClosure(
    String action, {
    String? confirmationToken,
    String? sessionId,
  }) async {
    if (!hasSession || _disposed) return;
    if (action == 'erasure' &&
        (confirmationToken == null ||
            !RegExp(r'^[a-fA-F0-9-]{36}:[A-Za-z0-9_-]{43}$')
                .hasMatch(confirmationToken))) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    if (action == 'current' &&
        (sessionId == null ||
            !RegExp(
              r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$',
            ).hasMatch(sessionId))) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    _loggingOut = true;
    _scope.cancel();
    try {
      await _rotation;
    } on ApiFailure {
      /* Rotation already closed the session. */
    }
    if (_tokens == null || _disposed) {
      _loggingOut = false;
      return;
    }
    final used = _tokens!, generation = _generation;
    try {
      await _write('closing');
    } on ApiFailure catch (e) {
      _generation++;
      _tokens = null;
      identity = null;
      consents = null;
      _loggingOut = false;
      phase = SessionPhase.storageFailure;
      _setFailure(e);
      _notify();
      return;
    }
    if (_disposed || generation != _generation) {
      _loggingOut = false;
      return;
    }
    phase = SessionPhase.synchronizing;
    resourceRevision++;
    _notify();
    var resultNotice = action == 'erasure'
        ? 'erasure_unconfirmed'
        : 'logout_unconfirmed';
    try {
      final result = await repository.api.requestJson(
        action == 'all' ? 'POST' : 'DELETE',
        action == 'erasure'
            ? '/api/users/me'
            : action == 'all'
            ? '/api/auth/logout-all'
            : '/api/auth/sessions/$sessionId',
        bearer: used.accessToken,
        expectedStatus: action == 'erasure'
            ? 202
            : action == 'all'
            ? 200
            : 204,
        body: action == 'erasure'
            ? {'confirmation_token': confirmationToken}
            : action == 'all'
            ? {'confirm': true}
            : null,
      );
      if (action == 'erasure') {
        final j = jsonObject(result);
        final id = jsonString(j, 'request_id');
        if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id) ||
            j['status'] != 'in_progress') {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        resultNotice = 'erasure_accepted';
      } else {
        if (action == 'all' &&
            jsonField<int>(jsonObject(result), 'revoked_sessions') < 0) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        resultNotice = action == 'all'
            ? 'logout_all_confirmed'
            : 'logout_confirmed';
      }
    } on ApiFailure catch (e) {
      if (action == 'erasure' &&
          [
            'invalid_or_expired_deletion_token',
            'invalid_account_deletion_payload',
            'account_deletion_unavailable',
            'account_not_found',
          ].contains(e.code)) {
        resultNotice = 'erasure_not_accepted';
      }
    } catch (_) {
      /* Result remains unknown, never retry a terminal mutation. */
    }
    if (!_disposed && generation == _generation) {
      await _invalidate(const ApiFailure(ApiFailureKind.unauthenticated));
      notice = resultNotice;
      if (phase == SessionPhase.signedOut) failure = null;
    }
    _loggingOut = false;
    _notify();
  }

  void _acceptConsents(ConsentState state) {
    final fingerprint = state.consents
        .map(
          (c) =>
              '${c.type.name}:${c.granted}:${c.documentVersion}:${c.requiredVersion}',
        )
        .join('|');
    if (_consentFingerprint != null && _consentFingerprint != fingerprint) {
      resourceRevision++;
    }
    _consentFingerprint = fingerprint;
    consents = state;
  }

  @override
  Future<void> synchronize() {
    if (_sync case final pending?) return pending;
    final task = _synchronize();
    _sync = task;
    return task.whenComplete(() {
      if (identical(_sync, task)) _sync = null;
    });
  }

  Future<void> _synchronize() async {
    if (!hasSession || _disposed || retrySeconds > 0) return;
    final generation = _generation;
    final revision = localizationRevision;
    final requestLanguage = language;
    _synchronizing = true;
    // Keep the existing form alive when returning from a legal document.
    // Unsaved choices survive only while the server document versions match.
    if (identity == null || consents == null) {
      phase = SessionPhase.synchronizing;
    }
    failure = null;
    _notify();
    try {
      final me = MobileIdentity.fromJson(
        await _authorized('GET', '/api/auth/me', language: requestLanguage),
      );
      if (identity != null && identity!.userId != me.userId) {
        await _invalidate(const ApiFailure(ApiFailureKind.sessionUncertain));
        return;
      }
      final state = ConsentState.fromJson(
        await _authorized(
          'GET',
          '/api/users/me/consents',
          language: requestLanguage,
        ),
      );
      if (generation != _generation || _loggingOut || _disposed) return;
      if (revision != localizationRevision) return;
      identity = me;
      _acceptConsents(state);
      _applyConsentPhase(state);
    } on ApiFailure catch (error) {
      if (generation != _generation || _loggingOut || _disposed) return;
      if (revision != localizationRevision) return;
      if (hasSession) {
        phase = SessionPhase.unavailable;
        _setFailure(error);
      }
    } finally {
      _synchronizing = false;
      _notify();
    }
  }

  void _applyConsentPhase(ConsentState state) {
    // No local inference of profile/discovery readiness.
    phase = state.onboardingComplete && state.requiredActions.isEmpty
        ? SessionPhase.ready
        : SessionPhase.needsConsents;
  }

  @override
  Future<void> saveConsents(
    Map<ConsentType, bool> changes,
    Map<ConsentType, String> displayedVersions, {
    Map<ConsentType, PublicConsent>? displayedDocuments,
  }) async {
    if (_disposed || !hasSession) {
      throw const ApiFailure(ApiFailureKind.unauthenticated);
    }
    if (_saving) throw const ApiFailure(ApiFailureKind.conflict);
    if (changes.isEmpty) return;
    if (retrySeconds > 0) throw failure!;
    final requestLanguage = language;
    final documents =
        displayedDocuments ??
        {
          for (final consent in consents?.consents ?? <PublicConsent>[])
            consent.type: consent,
        };
    _saving = true;
    failure = null;
    final generation = _generation;
    try {
      final current = ConsentState.fromJson(
        await _authorized(
          'GET',
          '/api/users/me/consents',
          language: requestLanguage,
        ),
      );
      if (requestLanguage != language ||
          changes.keys.any((type) {
            final next = current.consents.firstWhere((c) => c.type == type);
            final shown = documents[type];
            return next.requiredVersion != displayedVersions[type] ||
                shown == null ||
                next.documentUrl != shown.documentUrl ||
                next.documentLanguage != shown.documentLanguage;
          })) {
        if (requestLanguage == language) {
          _acceptConsents(current);
          _applyConsentPhase(current);
          _notify();
        }
        throw const ApiFailure(
          ApiFailureKind.conflict,
          code: 'legal_documents_changed',
        );
      }
      final state = ConsentState.fromJson(
        await _authorized(
          'PUT',
          '/api/users/me/consents',
          language: requestLanguage,
          body: {
            'consents': changes.entries
                .map(
                  (e) => {'consent_type': e.key.wireName, 'granted': e.value},
                )
                .toList(growable: false),
          },
        ),
      );
      if (generation != _generation || _loggingOut || _disposed) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      if (requestLanguage != language) {
        await _reloadLanguage();
        return;
      }
      _acceptConsents(state);
      identity = MobileIdentity(identity!.userId, state.onboardingComplete);
      _applyConsentPhase(state);
      _notify();
    } on ApiFailure catch (error) {
      if (generation == _generation && hasSession) {
        _setFailure(error);
        _notify();
      }
      rethrow;
    } finally {
      _saving = false;
    }
  }

  Future<void> _invalidate(ApiFailure reason) async {
    _generation++;
    _scope.cancel();
    _scope = RequestCancellation();
    _tokens = null;
    identity = null;
    consents = null;
    _consentFingerprint = null;
    failure = reason;
    try {
      await _write('signed_out');
      phase = SessionPhase.signedOut;
    } on ApiFailure catch (error) {
      phase = SessionPhase.storageFailure;
      failure = error;
    }
    _notify();
  }

  @override
  Future<void> logout() =>
      _terminal ??
      (_logout ??= _performLogout().whenComplete(() {
        _logout = null;
      }));

  Future<void> _performLogout() async {
    _loggingOut = true;
    _scope.cancel();
    phase = SessionPhase.synchronizing;
    _notify();
    // Let a rotation finish, then revoke its latest family credentials.
    try {
      await _rotation;
    } on ApiFailure {
      /* Invalidated by rotation. */
    }
    final tokens = _tokens;
    var confirmed = false;
    if (tokens != null) {
      try {
        await repository.logout(tokens);
        confirmed = true;
      } on ApiFailure {
        /* Local logout still proceeds. No blind mutation replay. */
      }
    }
    await _invalidate(const ApiFailure(ApiFailureKind.unauthenticated));
    if (phase == SessionPhase.signedOut) {
      failure = null;
      notice = confirmed ? 'logout_confirmed' : 'logout_unconfirmed';
    }
    _loggingOut = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer.cancel();
    _scope.cancel();
    _languageChanges?.removeListener(_languageChanged);
    repository.api.close();
    super.dispose();
  }
}
