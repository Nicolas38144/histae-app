import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';

Matcher failureKind(ApiFailureKind kind) =>
    throwsA(isA<ApiFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  ApiClient api(
    http.Client client, {
    Duration timeout = const Duration(seconds: 2),
    DateTime Function()? now,
  }) {
    final api = ApiClient(
      origin: Uri.parse('https://api.example'),
      client: client,
      timeout: timeout,
      now: now,
    );
    addTearDown(api.close);
    return api;
  }

  test(
    'public request uses one /api, JSON and a UUID v4 without a Bearer',
    () async {
      final ids = <String>{};
      final client = api(
        MockClient((request) async {
          expect(request.url.toString(), 'https://api.example/api/plans');
          expect(request.method, 'GET');
          expect(request.headers['Accept'], 'application/json');
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(
            request.headers['X-Request-ID'],
            matches(
              RegExp(
                r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
              ),
            ),
          );
          ids.add(request.headers['X-Request-ID']!);
          expect(request.followRedirects, isFalse);
          return http.Response('{"plans":[]}', 200);
        }),
      );
      expect(await client.getJson('/api/plans'), {'plans': []});
      await client.getJson('/api/plans');
      expect(ids, hasLength(2));
    },
  );

  final statuses = <int, ApiFailureKind>{
    400: ApiFailureKind.validation,
    401: ApiFailureKind.unauthenticated,
    403: ApiFailureKind.forbidden,
    404: ApiFailureKind.notFound,
    409: ApiFailureKind.conflict,
    410: ApiFailureKind.expired,
    413: ApiFailureKind.payloadTooLarge,
    429: ApiFailureKind.rateLimited,
    503: ApiFailureKind.unavailable,
    500: ApiFailureKind.server,
    302: ApiFailureKind.unexpected,
  };
  for (final entry in statuses.entries) {
    test(
      'maps HTTP ${entry.key}, ignores English message and never retries',
      () async {
        var calls = 0;
        final client = api(
          MockClient((request) async {
            calls++;
            return http.Response(
              '{"error":{"code":"example","message":"private"}}',
              entry.key,
              headers: {'x-request-id': 'malicious private value'},
            );
          }),
        );
        await expectLater(
          client.getJson('/api/plans'),
          failureKind(entry.value),
        );
        expect(calls, 1);
      },
    );
  }
  for (final entry in {
    'required_consent_missing': (403, ApiFailureKind.consentRequired),
    'onboarding_incomplete': (403, ApiFailureKind.consentRequired),
    'discovery_not_ready': (409, ApiFailureKind.discoveryNotReady),
    'continuation_quota_reached': (403, ApiFailureKind.quota),
  }.entries) {
    test('interprets the contract code ${entry.key}', () async {
      final client = api(
        MockClient(
          (_) async => http.Response(
            '{"error":{"code":"${entry.key}","message":"unrelated text"}}',
            entry.value.$1,
          ),
        ),
      );
      await expectLater(
        client.getJson('/api/plans'),
        failureKind(entry.value.$2),
      );
    });
  }

  test('retains a safe request ID and parses Retry-After seconds', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final now = DateTime.utc(2026, 10, 15);
    final client = api(
      MockClient(
        (_) async => http.Response(
          '{"error":{"code":"rate_limit_exceeded","message":"private"}}',
          429,
          headers: {'retry-after': '12', 'x-request-id': id},
        ),
      ),
      now: () => now,
    );
    try {
      await client.getJson('/api/plans');
      fail('Expected failure');
    } on ApiFailure catch (error) {
      expect(error.retryAt, now.add(const Duration(seconds: 12)));
      expect(error.requestId, id);
      expect(error.code, 'rate_limit_exceeded');
      expect(error.toString(), isNot(contains('private')));
    }
  });
  test(
    'parses an HTTP date even when an unavailable proxy returns HTML',
    () async {
      final date = DateTime.utc(2026, 10, 15, 12);
      final client = api(
        MockClient(
          (_) async => http.Response(
            '<html>private</html>',
            503,
            headers: {'retry-after': HttpDate.format(date)},
          ),
        ),
      );
      await expectLater(
        client.getJson('/api/plans'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', ApiFailureKind.unavailable)
              .having((e) => e.retryAt, 'retry date', date),
        ),
      );
    },
  );
  test('invalid Retry-After does not hide the server error', () async {
    final client = api(
      MockClient(
        (_) async =>
            http.Response('{}', 429, headers: {'retry-after': 'bad-date'}),
      ),
    );
    await expectLater(
      client.getJson('/api/plans'),
      failureKind(ApiFailureKind.rateLimited),
    );
  });
  test(
    'handles 204 without JSON and rejects malformed successful JSON',
    () async {
      expect(
        await api(MockClient((_) async => http.Response('', 204)))
            .getJson('/api/plans'),
        isNull,
      );
      await expectLater(
        api(MockClient((_) async => http.Response('invalid', 200)))
            .getJson('/api/plans'),
        failureKind(ApiFailureKind.invalidResponse),
      );
    },
  );
  test(
    'maps network failure without retaining private exception text',
    () async {
      final client = api(
        MockClient((_) async => throw http.ClientException('private URL')),
      );
      await expectLater(
        client.getJson('/api/plans'),
        failureKind(ApiFailureKind.network),
      );
    },
  );
  test('pre-cancelled requests never reach the transport', () async {
    final cancellation = RequestCancellation()..cancel();
    final client = api(
      MockClient((_) async => fail('Request must not be sent')),
    );
    await expectLater(
      client.getJson('/api/plans', cancellation: cancellation),
      failureKind(ApiFailureKind.cancelled),
    );
  });

  test(
    'timeout aborts a real HTTP response while its body is stalled',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodyStarted = Completer<void>();
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{');
        await request.response.flush();
        bodyStarted.complete();
      });
      final client = ApiClient(
        origin: Uri.parse('http://127.0.0.1:${server.port}'),
        timeout: const Duration(milliseconds: 250),
      );
      addTearDown(() async {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      });
      final result = client.getJson('/api/plans');
      final assertion = expectLater(
        result,
        failureKind(ApiFailureKind.timeout),
      );
      await bodyStarted.future;
      await assertion;
    },
  );
  test('explicit cancellation aborts a real request before headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final started = Completer<void>();
    final subscription = server.listen((_) {
      started.complete();
    });
    final client = ApiClient(
      origin: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    addTearDown(() async {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    });
    final cancellation = RequestCancellation();
    final result = client.getJson('/api/plans', cancellation: cancellation);
    final assertion = expectLater(
      result,
      failureKind(ApiFailureKind.cancelled),
    );
    await started.future;
    cancellation.cancel();
    await assertion;
  });
}
