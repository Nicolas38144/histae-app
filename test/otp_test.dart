import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/otp_controller.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/auth_repository.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';

void main() {
  test('OTP summaries expose only the country and last two digits and clear with the intention', () async {
    expect(maskFrenchPhone('+33 (6) 12.34-56 78'), '+33 • •• •• •• 78');
    expect(maskFrenchPhone('+336123456'), isNull);
    expect(maskFrenchPhone('+32612345678'), isNull);
    final session = testSession(
      (request) async => defaultAuthResponse(request),
    );
    addTearDown(session.dispose);
    final controller = OtpController(session);
    addTearDown(controller.dispose);
    expect(controller.maskedPhone, isNull);
    await controller.send('+33612345678');
    expect(controller.maskedPhone, '+33 • •• •• •• 78');
    controller.changePhone();
    expect(controller.maskedPhone, isNull);
  });
  test('French country selection normalizes national input and international autofill', () {
    for (final input in [
      '06 12 34 56 78',
      '6 12 34 56 78',
      '+33 (6) 12.34-56 78',
    ]) {
      expect(PhoneCountry.france.normalize(input), '+33612345678');
    }
    for (final input in [
      '+32612345678',
      '0012345678',
      '061234567',
      '06123456789',
      'abc',
    ]) {
      expect(PhoneCountry.france.normalize(input), isNull);
    }
  });

  test('sign-up opens generic OTP entry without claiming delivery or authentication', () async {
    final bodies = <Object?>[];
    final session = testSession((request) async {
      bodies.add(jsonDecode(request.body));
      return jsonResponse({
        'message': 'accepted',
        'resend_after_seconds': 60,
      }, 202);
    });
    addTearDown(session.dispose);
    final controller = OtpController(session, registration: true);
    addTearDown(controller.dispose);
    await controller.send('+33612345678');
    expect(bodies.single, {
      'phone_number': '+33612345678',
      'registration': true,
    });
    expect(controller.requested, isTrue);
    expect(controller.hasIntention, isTrue);
    expect(controller.failure, isNull);
    expect(controller.canRetrySend, isFalse);
    expect(controller.resendSeconds, greaterThanOrEqualTo(59));
    expect(session.hasSession, isFalse);
  });
  test(
    'French numbers follow Rust normalization and exclude invalid inputs',
    () {
      expect(normalizeFrenchPhone(' +33 (6) 12.34-56 78 '), '+33612345678');
      for (final phone in [
        '0612345678',
        '+33012345678',
        '+32612345678',
        '+3361234567',
        '+336123456789',
      ]) {
        expect(normalizeFrenchPhone(phone), isNull);
      }
    },
  );

  test('uncertain delivery resumes the same UUID and parameters; explicit resend changes UUID', () async {
    var now = DateTime.now();
    final keys = <String>[];
    final bodies = <Object?>[];
    final session = testSession((request) async {
      keys.add(request.headers['Idempotency-Key']!);
      bodies.add(jsonDecode(request.body));
      expect(request.headers['Authorization'], isNull);
      return keys.length == 1
          ? apiError(503, 'otp_delivery_unknown')
          : defaultAuthResponse(request);
    });
    addTearDown(session.dispose);
    final controller = OtpController(session, now: () => now);
    addTearDown(controller.dispose);
    await controller.send('+33 6 12 34 56 78');
    expect(controller.requested, isTrue);
    expect(controller.failure!.code, 'otp_delivery_unknown');
    expect(controller.canRetrySend, isTrue);
    await controller.send('+33612345678', newIntention: false);
    expect(controller.canRetrySend, isFalse);
    expect(keys[1], keys[0]);
    expect(bodies[1], bodies[0]);
    await controller.send('+33612345678');
    expect(keys, hasLength(2));
    now = now.add(const Duration(seconds: 61));
    await controller.send('+33612345678');
    expect(keys[2], isNot(keys[0]));
    expect(
      keys.last,
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
    expect(bodies, everyElement({'phone_number': '+33612345678'}));
  });

  test('OTP send is single-flight and cannot reuse an intention for a different phone', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final session = testSession((request) {
      calls++;
      return pending.future;
    });
    addTearDown(session.dispose);
    final controller = OtpController(session);
    addTearDown(controller.dispose);
    final first = controller.send('+33612345678');
    await controller.send('+33612345678');
    pending.complete(jsonResponse({'message': 'accepted'}, 202));
    await first;
    await controller.send('+33712345678', newIntention: false);
    expect(calls, 1);
  });

  test('verification errors leave OTP outside session refresh logic', () async {
    var verifies = 0;
    var sends = 0;
    var refreshes = 0;
    final session = testSession((request) async {
      if (request.url.path == '/api/auth/refresh') refreshes++;
      if (request.url.path == '/api/auth/otp/send') sends++;
      if (request.url.path == '/api/auth/otp/verify') {
        verifies++;
        expect(jsonDecode(request.body), {
          'phone_number': '+33612345678',
          'otp': '123456',
        });
        expect(request.headers['Idempotency-Key'], isNull);
        return apiError(401, 'invalid_or_expired_otp');
      }
      return defaultAuthResponse(request);
    });
    addTearDown(session.dispose);
    await session.start();
    final controller = OtpController(session);
    addTearDown(controller.dispose);
    await controller.send('+33612345678');
    await controller.verify('123456');
    await controller.verify('123456');
    expect(verifies, 2);
    expect(refreshes, 0);
    expect(controller.failure!.code, 'invalid_or_expired_otp');
    expect(controller.canRetrySend, isFalse);
    await controller.retrySend();
    expect(sends, 1);
    expect(session.phase, SessionPhase.signedOut);
  });

  test(
    'lost verification response requires a new code, never an automatic replay',
    () async {
      var verifies = 0;
      var now = DateTime.now();
      final session = testSession((request) async {
        if (request.url.path == '/api/auth/otp/verify') {
          verifies++;
          throw http.ClientException('Synthetic response lost');
        }
        return defaultAuthResponse(request);
      });
      addTearDown(session.dispose);
      final controller = OtpController(session, now: () => now);
      addTearDown(controller.dispose);
      await controller.send('+33612345678');
      await controller.verify('123456');
      expect(controller.verificationUncertain, isTrue);
      expect(controller.canRetrySend, isFalse);
      await controller.retrySend();
      await controller.verify('123456');
      expect(verifies, 1);
      now = now.add(const Duration(seconds: 61));
      await controller.send('+33612345678');
      expect(controller.verificationUncertain, isFalse);
    },
  );

  test('Retry-After covers send, verify and phone edits without background resends', () async {
    var now = DateTime.utc(2026, 10, 16);
    var calls = 0;
    final session = testSession((request) async {
      calls++;
      return apiError(429, 'otp_rate_limit_exceeded', retryAfter: '30');
    });
    addTearDown(session.dispose);
    final controller = OtpController(session, now: () => now);
    addTearDown(controller.dispose);
    // API time is real, so compare advancement rather than an exact test date.
    now = DateTime.now();
    await controller.send('+33612345678');
    expect(controller.retrySeconds, greaterThanOrEqualTo(29));
    controller.changePhone();
    await controller.send('+33712345678');
    expect(calls, 1);
    now = now.add(const Duration(seconds: 61));
    expect(calls, 1);
    await controller.send('+33712345678');
    expect(calls, 2);
  });

  test(
    'resend cooldown preserves verification and survives editing the phone',
    () async {
      var now = DateTime.now();
      var sends = 0;
      var verifies = 0;
      final session = testSession((request) async {
        if (request.url.path.endsWith('/send')) {
          sends++;
          return jsonResponse({'resend_after_seconds': 90}, 202);
        }
        verifies++;
        return apiError(401, 'invalid_or_expired_otp');
      });
      addTearDown(session.dispose);
      final controller = OtpController(session, now: () => now);
      addTearDown(controller.dispose);
      await controller.send('+33612345678');
      expect(controller.resendSeconds, 90);
      await controller.verify('123456');
      expect(verifies, 1);
      expect(controller.retrySeconds, 0);
      expect(controller.resendSeconds, 90);
      controller.changePhone();
      await controller.send('+33712345678');
      expect(sends, 1);
      now = now.add(const Duration(seconds: 91));
      await controller.send('+33712345678');
      expect(sends, 2);
    },
  );

  test(
    'server resend cooldown still permits entering an existing code',
    () async {
      var verifies = 0;
      final session = testSession((request) async {
        if (request.url.path.endsWith('/send')) {
          return apiError(429, 'otp_resend_too_soon', retryAfter: '30');
        }
        verifies++;
        return apiError(401, 'invalid_or_expired_otp');
      });
      addTearDown(session.dispose);
      final controller = OtpController(session);
      addTearDown(controller.dispose);
      await controller.send('+33612345678');
      expect(controller.requested, isTrue);
      expect(controller.retrySeconds, 0);
      expect(controller.resendSeconds, greaterThan(0));
      await controller.verify('123456');
      expect(verifies, 1);
    },
  );

  test('accepted means HTTP 202, not SMS receipt or a session', () async {
    final session = testSession(
      (request) async => defaultAuthResponse(request),
    );
    addTearDown(session.dispose);
    final controller = OtpController(session);
    addTearDown(controller.dispose);
    await controller.send('+33612345678');
    expect(controller.notice, 'otp_accepted');
    expect(session.hasSession, isFalse);
  });

  test(
    'a malformed successful token response cannot establish a fake session',
    () async {
      final session = testSession(
        (request) async => request.url.path.endsWith('verify')
            ? jsonResponse({'access_token': 'test-access-without-refresh'})
            : defaultAuthResponse(request),
      );
      addTearDown(session.dispose);
      final controller = OtpController(session);
      addTearDown(controller.dispose);
      await controller.send('+33612345678');
      await controller.verify('123456');
      expect(controller.verificationUncertain, isTrue);
      expect(controller.failure!.kind, ApiFailureKind.invalidResponse);
      expect(session.hasSession, isFalse);
    },
  );
}
