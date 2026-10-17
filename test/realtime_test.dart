import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/auth_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';

class StreamingTestClient extends http.BaseClient {
  StreamingTestClient(this.json, this.events);
  final MockClient json;
  final Future<http.StreamedResponse> Function(http.BaseRequest) events;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) =>
      r.url.path.endsWith('/events') ? events(r) : json.send(r);
  @override
  void close() => json.close();
}

void main() {
  test('SSE Bearer 401 shares one refresh with JSON, stream cancellation aborts HTTP and revoked session fails closed', () async {
    var rotations = 0, oldCalls = 0, aborted = false;
    final oldRequestsArrived = Completer<void>();
    final stream = StreamController<List<int>>();
    http.Response expired() {
      if (++oldCalls == 2) oldRequestsArrived.complete();
      return apiError(401, 'invalid_or_expired_access_token');
    }

    final client = StreamingTestClient(
      MockClient((r) async {
        if (r.url.path.endsWith('/refresh')) {
          rotations++;
          await oldRequestsArrived.future;
          return jsonResponse(tokenJson(rotatedTokens));
        }
        if (r.url.path == '/api/protected') {
          if (r.headers['Authorization'] ==
              'Bearer ${testTokens.accessToken}') {
            return expired();
          }
          return jsonResponse({'ok': true});
        }
        return defaultAuthResponse(r, complete: true);
      }),
      (r) async {
        expect(r.headers['Accept'], 'text/event-stream');
        expect(r.followRedirects, isFalse);
        expect(r.url.query, isEmpty);
        if (r.headers['Authorization'] == 'Bearer ${testTokens.accessToken}') {
          final response = expired();
          return http.StreamedResponse(
            Stream.value(response.bodyBytes),
            response.statusCode,
            headers: response.headers,
          );
        }
        expect(
          r.headers['Authorization'],
          'Bearer ${rotatedTokens.accessToken}',
        );
        unawaited(
          (r as http.Abortable).abortTrigger!.then((_) {
            aborted = true;
            if (!stream.isClosed) unawaited(stream.close());
          }),
        );
        return http.StreamedResponse(
          stream.stream,
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      },
    );
    final session = SessionController(
      AuthRepository(
        ApiClient(origin: Uri.parse('https://api.example'), client: client),
      ),
      MemorySessionVault(),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final life = RequestCancellation();
    final values = await Future.wait([
      session.openEvents(life),
      session.request(
        'GET',
        '/api/protected',
        expectedStatus: 200,
        replayAfterRefresh: true,
      ),
    ]);
    expect(rotations, 1);
    expect(oldCalls, 2);
    final connection = values.first as ApiEventStream;
    final received = connection.bytes.toList();
    stream.add(utf8.encode(': alive\n'));
    life.cancel();
    await received;
    expect(aborted, isTrue);
    // A second transport returns the definitive revoked-session code.
    final revoked = testSession(
      (r) async => r.url.path.endsWith('/events')
          ? apiError(401, 'authentication_required')
          : defaultAuthResponse(r, complete: true),
    );
    addTearDown(revoked.dispose);
    await revoked.establish(testTokens);
    await expectLater(
      revoked.openEvents(RequestCancellation()),
      throwsA(isA<ApiFailure>()),
    );
    expect(revoked.hasSession, isFalse);
  });

  test('rapid realtime start/stop keeps one useful connection, decodes fragmented UTF8, deduplicates IDs and stops reconnect timers', () async {
    final session = testSession(
      (r) async => defaultAuthResponse(r, complete: true),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    var active = 0, peak = 0, opened = 0;
    final streams = <StreamController<List<int>>>[];
    final signals = <MobileSignal>[];
    final client = RealtimeClient(
      session,
      open: (life) async {
        opened++;
        active++;
        if (active > peak) peak = active;
        final stream = StreamController<List<int>>();
        streams.add(stream);
        var closed = false;
        return ApiEventStream(stream.stream, () {
          if (closed) return;
          closed = true;
          active--;
          unawaited(stream.close());
        });
      },
    )..onSignal = signals.add;
    addTearDown(client.dispose);
    client.start();
    client.start();
    await Future<void>.delayed(Duration.zero);
    final payload = utf8.encode(
      ': café 🌿\nevent: connected\ndata: {"server_time":"2026-10-16T12:00:00Z"}\n\nid: $outgoingId\nevent: match.created\ndata: {"match_id":"$testMatch"}\n\n',
    );
    for (final byte in payload) {
      streams.first.add([byte]);
    }
    streams.first.add(
      utf8.encode(
        'id: $outgoingId\nevent: match.created\ndata: {"match_id":"$testMatch"}\n\n',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(signals.map((s) => s.type), ['connected', 'match.created']);
    client.stop();
    client.start();
    client.start();
    await Future<void>.delayed(Duration.zero);
    expect(peak, 1);
    expect(opened, 2);
    await streams.last.close();
    await Future<void>.delayed(Duration.zero);
    client.stop();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(active, 0);
    expect(opened, 2);
  });
}
