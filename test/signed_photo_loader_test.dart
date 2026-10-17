import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/core/network/signed_photo_loader.dart';
import 'package:http/http.dart' as http;

class _PhotoClient extends http.BaseClient {
  _PhotoClient(this.response);
  final Future<http.StreamedResponse> Function() response;
  http.BaseRequest? request;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    this.request = request;
    return response();
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  test('signed photos use no Bearer or redirects, enforce the stream budget and reject responses arriving after cancellation', () async {
    final client = _PhotoClient(
      () async => http.StreamedResponse(Stream.value([1, 2, 3]), 200),
    );
    final loader = SignedPhotoLoader(clientFactory: () => client);
    expect(
      () => loader.load('http://storage.example/photo'),
      throwsA(isA<ApiFailure>()),
    );
    expect(client.request, isNull);
    final download = loader.load(
      'https://storage.example/photo?signature=synthetic',
    );
    expect(await download.bytes, [1, 2, 3]);
    expect(client.request!.headers.containsKey('Authorization'), isFalse);
    expect(client.request!.followRedirects, isFalse);
    expect(client.closed, isTrue);

    final large = _PhotoClient(
      () async => http.StreamedResponse(
        Stream.value(Uint8List(SignedPhotoDownload.maxBytes + 1)),
        200,
      ),
    );
    final oversized = SignedPhotoLoader(clientFactory: () => large)
        .load('https://storage.example/photo');
    await expectLater(
      oversized.bytes,
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.payloadTooLarge,
        ),
      ),
    );
    expect(large.closed, isTrue);

    final response = Completer<http.StreamedResponse>();
    final late = _PhotoClient(() => response.future);
    final cancelled = SignedPhotoLoader(clientFactory: () => late)
        .load('https://storage.example/photo');
    final checked = expectLater(
      cancelled.bytes,
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.cancelled,
        ),
      ),
    );
    cancelled.cancel();
    response.complete(http.StreamedResponse(Stream.value([1]), 200));
    await checked;
    expect(late.closed, isTrue);
  });
}
