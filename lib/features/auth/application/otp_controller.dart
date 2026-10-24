import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../data/auth_repository.dart';
import 'session_controller.dart';

class OtpController extends ChangeNotifier {
  OtpController(
    this.session, {
    DateTime Function()? now,
    this.onAuthenticated,
    this.registration = false,
  }) : _now = now ?? DateTime.now;
  final SessionController session;
  final bool registration;
  final Future<void> Function(TokenPair tokens)? onAuthenticated;
  final DateTime Function() _now;
  String? _phone;
  String? _key;
  ApiLanguage? _language;
  bool _sendRetryPending = false;
  bool busy = false;
  bool requested = false;
  bool verificationUncertain = false;
  String? notice;
  ApiFailure? failure;
  DateTime? _retryAt;
  DateTime? _resendAt;
  late final RetryTicker _timer = RetryTicker(
    remaining: () => resendSeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  RequestCancellation? _request;
  bool _disposed = false;

  int get retrySeconds => retrySecondsUntil(_retryAt, now: _now());
  int get resendSeconds {
    final remaining = retrySecondsUntil(_resendAt, now: _now());
    return remaining > retrySeconds ? remaining : retrySeconds;
  }

  bool get hasIntention => _key != null;
  bool get canRetrySend => hasIntention && _sendRetryPending;
  String? get maskedPhone => _phone == null ? null : maskFrenchPhone(_phone!);
  // New send/resend explicitly creates an intention. Technical resume keeps
  // BOTH its phone and UUID, which are held in memory only.

  Future<void> send(String input, {bool newIntention = true}) async {
    if (busy || _disposed || retrySeconds > 0) return;
    if (newIntention && resendSeconds > 0) return;
    if (!newIntention && !canRetrySend) return;
    final phone = normalizeFrenchPhone(input);
    if (phone == null) {
      failure = const ApiFailure(
        ApiFailureKind.validation,
        code: 'invalid_phone_number',
      );
      notifyListeners();
      return;
    }
    if (newIntention) {
      _phone = phone;
      _key = newUuidV4();
      _language = session.language;
      _sendRetryPending = false;
      verificationUncertain = false;
      // A lost response may still have queued the request. Technical replay
      // keeps its UUID; requesting another SMS must wait.
      _resendAt = _now().add(const Duration(seconds: 60));
      _timer.restart();
    }
    if (_phone != phone || _key == null) return;
    await _run(() async {
      final receipt = await session.repository.sendOtp(
        _phone!,
        _key!,
        _request!,
        language: _language,
        registration: registration,
      );
      if (_disposed) return;
      _resendAt = _now().add(receipt.resendAfter);
      _timer.restart();
      requested = true;
      _sendRetryPending = false;
      verificationUncertain = false;
      notice = 'otp_accepted';
    }, sending: true);
  }

  /// Resolve only an uncertain send, keeping its phone, language and UUID.
  Future<void> retrySend() async {
    if (_phone case final phone?) {
      await send(phone, newIntention: false);
    }
  }

  Future<void> verify(String otp) async {
    if (busy ||
        !requested ||
        verificationUncertain ||
        _disposed ||
        retrySeconds > 0) {
      return;
    }
    _sendRetryPending = false;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      failure = const ApiFailure(
        ApiFailureKind.validation,
        code: 'invalid_otp_request',
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      try {
        final pair = await session.repository.verifyOtp(
          _phone!,
          otp,
          _request!,
        );
        if (!_disposed) {
          final complete = onAuthenticated;
          if (complete == null) {
            await session.establish(pair);
          } else {
            await complete(pair);
          }
        } else {
          // A known late login response can still be revoked. Never establish
          // a session after its login screen was abandoned.
          try {
            await session.repository.logout(pair);
          } on ApiFailure {
            /* Best effort. */
          }
        }
      } on ApiFailure catch (error) {
        if (error.statusCode == null ||
            error.kind == ApiFailureKind.invalidResponse ||
            error.kind == ApiFailureKind.server ||
            error.kind == ApiFailureKind.unavailable) {
          verificationUncertain = true;
        }
        rethrow;
      }
    }, sending: false);
  }

  Future<void> _run(
    Future<void> Function() action, {
    required bool sending,
  }) async {
    busy = true;
    failure = null;
    notice = null;
    _request = RequestCancellation();
    notifyListeners();
    try {
      await action();
    } on ApiFailure catch (error) {
      if (!_disposed) {
        failure = error;
        if (sending) {
          _sendRetryPending =
              error.code == 'otp_delivery_unknown' ||
              error.statusCode == null ||
              error.kind == ApiFailureKind.invalidResponse ||
              error.kind == ApiFailureKind.server;
          if (_sendRetryPending) requested = true; // A code may still arrive.
        }
        if (error.code == 'otp_resend_too_soon') {
          // Another device or app instance may already have requested a code.
          // This deadline limits sending, never verification of that code.
          requested = true;
          _resendAt = error.retryAt ?? _now().add(const Duration(seconds: 60));
          _retryAt = null;
        } else {
          _retryAt = error.retryAt;
        }
        _timer.cancel();
        if (resendSeconds > 0) {
          _timer.restart();
        }
      }
    } finally {
      _request?.cancel();
      _request = null;
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void changePhone() {
    if (busy) return;
    _phone = null;
    _key = null;
    _language = null;
    _sendRetryPending = false;
    requested = false;
    verificationUncertain = false;
    failure = null;
    notice = null;
    // Editing the phone does not bypass either resend or server limits.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request?.cancel();
    _timer.cancel();
    _phone = null;
    _key = null;
    _language = null;
    _sendRetryPending = false;
    super.dispose();
  }
}
