import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../data/auth_repository.dart';
import 'session_controller.dart';

class OtpController extends ChangeNotifier {
  OtpController(this.session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final SessionController session;
  final DateTime Function() _now;
  String? _phone;
  String? _key;
  bool busy = false;
  bool requested = false;
  bool verificationUncertain = false;
  String? notice;
  ApiFailure? failure;
  DateTime? _retryAt;
  late final RetryTicker _timer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  RequestCancellation? _request;
  bool _disposed = false;

  int get retrySeconds => retrySecondsUntil(_retryAt, now: _now());

  bool get canResume => _key != null;

  // New send/resend explicitly creates an intention. Technical resume keeps
  // BOTH its phone and UUID, which are held in memory only.
  Future<void> send(String input, {bool newIntention = true}) async {
    if (busy || _disposed || retrySeconds > 0) return;
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
      requested = false;
      verificationUncertain = false;
    }
    if (_phone != phone || _key == null) return;
    await _run(() async {
      await session.repository.sendOtp(_phone!, _key!, _request!);
      requested = true;
      verificationUncertain = false;
      notice = 'otp_accepted';
    });
  }

  Future<void> verify(String otp) async {
    if (busy ||
        !requested ||
        verificationUncertain ||
        _disposed ||
        retrySeconds > 0) {
      return;
    }
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
          await session.establish(pair);
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
    });
  }

  Future<void> _run(Future<void> Function() action) async {
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
        if (error.code == 'otp_delivery_unknown' ||
            error.statusCode == null ||
            error.kind == ApiFailureKind.invalidResponse ||
            error.kind == ApiFailureKind.server) {
          requested = true; // The original code may still arrive.
        }
        _retryAt = error.retryAt;
        _timer.cancel();
        if (retrySeconds > 0) {
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
    requested = false;
    verificationUncertain = false;
    failure = null;
    notice = null;
    // Keep any server Retry-After when the phone is edited.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request?.cancel();
    _timer.cancel();
    _phone = null;
    _key = null;
    super.dispose();
  }
}
