import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../consents/data/consent_state.dart';
import '../data/auth_repository.dart';
import '../data/session_vault.dart';

enum SessionPhase {
  restoring,
  signedOut,
  synchronizing,
  needsConsents,
  ready,
  unavailable,
  storageFailure,
}

class SessionController extends ChangeNotifier {
  SessionController(this.repository, this._vault);
  final AuthRepository repository;
  final SessionVault _vault;
  SessionPhase phase = SessionPhase.restoring;
  MobileIdentity? identity;
  ConsentState? consents;
  ApiFailure? failure;
  String? notice;
  TokenPair? _tokens;
  RequestCancellation _scope = RequestCancellation();
  Future<void>? _start;
  Future<void>? _sync;
  Future<void>? _rotation;
  Future<void>? _logout;
  int _generation = 0;
  bool _disposed = false;
  bool _loggingOut = false;
  bool _establishing = false;
  bool _saving = false;
  bool get isSaving => _saving;
  bool _synchronizing = false;
  bool get isSynchronizing => _synchronizing;
  Timer? _retryTimer;
  int get retrySeconds {
    final milliseconds =
        failure?.retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void _setFailure(ApiFailure error) {
    failure = error;
    _retryTimer?.cancel();
    if (retrySeconds > 0) {
      _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (retrySeconds == 0) timer.cancel();
        _notify();
      });
    }
  }

  String get _origin => repository.api.origin.toString();
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

  // Only L2's reads and identical consent PUTs are eligible for one replay.
  // A revoked session (authentication_required) is closed, never refreshed.
  Future<Object?> _authorized(
    String method,
    String path, {
    Object? body,
  }) async {
    final generation = _generation;
    if (_rotation case final pending?) await pending;
    final used = _tokens;
    if (used == null || _loggingOut || _disposed || generation != _generation) {
      throw const ApiFailure(ApiFailureKind.unauthenticated);
    }
    Future<Object?> send(TokenPair tokens) async {
      final result = await repository.api.requestJson(
        method,
        path,
        body: body,
        bearer: tokens.accessToken,
        cancellation: _scope,
        expectedStatus: 200,
      );
      if (generation != _generation || _loggingOut || _disposed) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      return result;
    }

    try {
      return await send(used);
    } on ApiFailure catch (error) {
      if (_disposed || _loggingOut || generation != _generation) rethrow;
      if (error.statusCode == 401 &&
          error.code == 'invalid_or_expired_access_token') {
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
        await _authorized('GET', '/api/auth/me'),
      );
      if (identity != null && identity!.userId != me.userId) {
        await _invalidate(const ApiFailure(ApiFailureKind.sessionUncertain));
        return;
      }
      final state = ConsentState.fromJson(
        await _authorized('GET', '/api/users/me/consents'),
      );
      if (generation != _generation || _loggingOut || _disposed) return;
      identity = me;
      consents = state;
      _applyConsentPhase(state);
    } on ApiFailure catch (error) {
      if (generation != _generation || _loggingOut || _disposed) return;
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

  Future<void> saveConsents(
    Map<ConsentType, bool> changes,
    Map<ConsentType, String> displayedVersions,
  ) async {
    if (_disposed || !hasSession) {
      throw const ApiFailure(ApiFailureKind.unauthenticated);
    }
    if (_saving) throw const ApiFailure(ApiFailureKind.conflict);
    if (changes.isEmpty) return;
    if (retrySeconds > 0) throw failure!;
    _saving = true;
    failure = null;
    final generation = _generation;
    try {
      final current = ConsentState.fromJson(
        await _authorized('GET', '/api/users/me/consents'),
      );
      if (changes.keys.any(
        (type) =>
            current.consents
                .firstWhere((c) => c.type == type)
                .requiredVersion !=
            displayedVersions[type],
      )) {
        consents = current;
        _applyConsentPhase(current);
        _notify();
        throw const ApiFailure(
          ApiFailureKind.conflict,
          code: 'legal_documents_changed',
        );
      }
      final state = ConsentState.fromJson(
        await _authorized(
          'PUT',
          '/api/users/me/consents',
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
      consents = state;
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

  Future<void> logout() => _logout ??= _performLogout().whenComplete(() {
    _logout = null;
  });
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
    _retryTimer?.cancel();
    _scope.cancel();
    repository.api.close();
    super.dispose();
  }
}
