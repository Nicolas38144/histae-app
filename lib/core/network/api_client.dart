import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_failure.dart';

class RequestCancellation {
  final _completer = Completer<void>();
  Future<void> get whenCancelled => _completer.future;
  bool get isCancelled => _completer.isCompleted;
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class ApiClient {
  ApiClient({
    required this.origin,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  final Uri origin;
  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _now;
  final _active = <RequestCancellation>{};
  bool _closed = false;

  // Reads only in L1. Mutations will need route-specific replay rules.
  // No automatic retry, refresh, redirect or private-data logging.
  Future<Object?> getJson(
    String path, {
    RequestCancellation? cancellation,
  }) async {
    if (_closed || (cancellation?.isCancelled ?? false)) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (!path.startsWith('/api/') ||
        path.contains('..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw ArgumentError('Expected a complete API path');
    }
    final abort = RequestCancellation();
    _active.add(abort);
    final requestId = _uuidV4();
    final request =
        http.AbortableRequest(
            'GET',
            origin.resolve(path),
            abortTrigger: cancellation == null
                ? abort.whenCancelled
                : Future.any([abort.whenCancelled, cancellation.whenCancelled]),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'X-Request-ID': requestId,
          });
    try {
      final response = await _read(request).timeout(
        timeout,
        onTimeout: () {
          abort.cancel();
          throw ApiFailure(ApiFailureKind.timeout, requestId: requestId);
        },
      );
      final serverId = response.headers['x-request-id'];
      final diagnosticId = _validUuidV4(serverId) ? serverId : requestId;
      Object? body;
      try {
        if (response.statusCode != 204) {
          body = jsonDecode(utf8.decode(response.bodyBytes));
        }
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw ApiFailure(
            ApiFailureKind.invalidResponse,
            statusCode: response.statusCode,
            requestId: diagnosticId,
          );
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return body;
      final error = body is Map<String, dynamic> ? body['error'] : null;
      final code = error is Map<String, dynamic> && error['code'] is String
          ? error['code'] as String
          : null;
      throw ApiFailure(
        ApiFailure.classify(response.statusCode, code),
        statusCode: response.statusCode,
        code: code,
        requestId: diagnosticId,
        retryAt: _retryAt(response.headers['retry-after']),
      );
    } on http.RequestAbortedException {
      throw ApiFailure(ApiFailureKind.cancelled, requestId: requestId);
    } on TimeoutException {
      throw ApiFailure(ApiFailureKind.timeout, requestId: requestId);
    } on SocketException {
      throw ApiFailure(ApiFailureKind.network, requestId: requestId);
    } on http.ClientException {
      throw ApiFailure(ApiFailureKind.network, requestId: requestId);
    } on IOException {
      throw ApiFailure(ApiFailureKind.network, requestId: requestId);
    } finally {
      _active.remove(abort);
    }
  }

  Future<http.Response> _read(http.BaseRequest request) async =>
      http.Response.fromStream(await _client.send(request));

  DateTime? _retryAt(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) {
      if (seconds < 0) return null;
      // Do not permit an unusually large valid delay to enable early retry.
      final now = _now().toUtc();
      final latest = DateTime.utc(9999, 12, 31);
      if (seconds > latest.difference(now).inSeconds) return latest;
      return now.add(Duration(seconds: seconds));
    }
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final request in _active) {
      request.cancel();
    }
    _client.close();
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
bool _validUuidV4(String? value) =>
    value != null && _uuidPattern.hasMatch(value);

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
