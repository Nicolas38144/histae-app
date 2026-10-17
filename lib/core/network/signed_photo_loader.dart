import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_failure.dart';

typedef PhotoClientFactory = http.Client Function();

/// Downloads a signed storage resource without authentication headers, redirects,
/// persistence or logging. Authorization to reveal it belongs to the caller.
class SignedPhotoLoader {
  SignedPhotoLoader({PhotoClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final PhotoClientFactory _clientFactory;
  SignedPhotoDownload load(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return SignedPhotoDownload._(_clientFactory(), uri);
  }
}

class SignedPhotoDownload {
  SignedPhotoDownload._(this._client, Uri uri) {
    bytes = _load(uri);
  }
  static const maxBytes = 5000000;
  final http.Client _client;
  bool _closed = false;
  late final Future<Uint8List> bytes;
  Future<Uint8List> _load(Uri uri) async {
    try {
      return await _read(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } finally {
      cancel();
    }
  }

  Future<Uint8List> _read(Uri uri) async {
    final response = await _client.send(
      http.Request('GET', uri)..followRedirects = false,
    );
    if (_closed) throw const ApiFailure(ApiFailureKind.cancelled);
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      throw const ApiFailure(ApiFailureKind.unavailable);
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (_closed) throw const ApiFailure(ApiFailureKind.cancelled);
      if (buffer.length + chunk.length > maxBytes) {
        throw const ApiFailure(ApiFailureKind.payloadTooLarge);
      }
      buffer.add(chunk);
    }
    if (_closed) throw const ApiFailure(ApiFailureKind.cancelled);
    return buffer.takeBytes();
  }

  void cancel() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
