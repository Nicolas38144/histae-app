import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_failure.dart';
import 'api_stream.dart';
import 'request_cancellation.dart';

export 'api_stream.dart';
export 'request_cancellation.dart';

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

  Future<Object?> getJson(String path, {RequestCancellation? cancellation}) =>
      requestJson('GET', path, cancellation: cancellation);

  Future<ApiEventStream> openEvents({
    required String bearer,
    required RequestCancellation cancellation,
  }) => _openAuthenticatedStream(
    bearer: bearer,
    cancellation: cancellation,
    dataExport: false,
  );

  Future<ApiDownload> openDataExport({
    required String bearer,
    required RequestCancellation cancellation,
  }) async => await _openAuthenticatedStream(
    bearer: bearer,
    cancellation: cancellation,
    dataExport: true,
  ) as ApiDownload;

  Future<ApiEventStream> _openAuthenticatedStream({
    required String bearer,
    required RequestCancellation cancellation,
    required bool dataExport,
  }) async {
    if (_closed || cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    final abort = RequestCancellation();
    _active.add(abort);
    final id = newUuidV4();
    void close() {
      abort.cancel();
      _active.remove(abort);
    }

    final request =
        http.AbortableRequest(
            'GET',
            origin.resolve(
              dataExport ? '/api/users/me/data-export' : '/api/users/me/events',
            ),
            abortTrigger: Future.any([
              abort.whenCancelled,
              cancellation.whenCancelled,
            ]),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': dataExport ? 'application/json' : 'text/event-stream',
            if (dataExport) 'Accept-Encoding': 'identity',
            'Authorization': 'Bearer $bearer',
            'X-Request-ID': id,
          });
    try {
      final response = await _client
          .send(request)
          .timeout(dataExport ? const Duration(minutes: 2) : timeout);
      if (response.statusCode != 200) {
        final data = <int>[];
        await for (final part in response.stream.timeout(timeout)) {
          if (data.length + part.length > 65536) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          data.addAll(part);
        }
        String? code;
        try {
          final json = jsonDecode(utf8.decode(data));
          final error = json is Map ? json['error'] : null;
          if (error is Map && error['code'] is String) {
            code = error['code'] as String;
          }
        } on FormatException {
          /* Only typed diagnostics are retained. */
        }
        throw ApiFailure(
          ApiFailure.classify(response.statusCode, code),
          statusCode: response.statusCode,
          code: code,
          requestId: id,
          retryAt: _retryAt(response.headers['retry-after']),
        );
      }
      if (response.headers['content-type']
              ?.split(';')
              .first
              .trim()
              .toLowerCase() !=
          (dataExport ? 'application/json' : 'text/event-stream')) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      Stream<List<int>> bytes() async* {
        try {
          yield* response.stream.timeout(
            Duration(seconds: dataExport ? 30 : 70),
          );
        } on http.RequestAbortedException {
          throw const ApiFailure(ApiFailureKind.cancelled);
        } on TimeoutException {
          throw const ApiFailure(ApiFailureKind.timeout);
        } catch (_) {
          throw const ApiFailure(ApiFailureKind.network);
        } finally {
          close();
        }
      }

      if (dataExport) {
        // Dart may decompress gzip without changing Content-Length. Request
        // identity so the on-disk byte count can be checked against that header.
        final encoding = response.headers['content-encoding']
            ?.trim()
            .toLowerCase();
        if (encoding != null && encoding != 'identity') {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        final length = int.tryParse(response.headers['content-length'] ?? '');
        if (length == null || length < 2) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        return ApiDownload(bytes(), close, length);
      }
      return ApiEventStream(bytes(), close);
    } on ApiFailure {
      close();
      rethrow;
    } on TimeoutException {
      close();
      throw ApiFailure(ApiFailureKind.timeout, requestId: id);
    } on http.RequestAbortedException {
      close();
      throw ApiFailure(ApiFailureKind.cancelled, requestId: id);
    } catch (_) {
      close();
      throw ApiFailure(ApiFailureKind.network, requestId: id);
    }
  }

  // The transport never retries or refreshes. Callers explicitly choose their
  // route's replay policy; request bodies and credentials are never logged.
  Future<Object?> requestJson(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    List<int>? photo,
    String? bearer,
    String? idempotencyKey,
    int? expectedStatus,
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
    final requestId = newUuidV4();
    final trigger = cancellation == null
        ? abort.whenCancelled
        : Future.any([abort.whenCancelled, cancellation.whenCancelled]);
    if (photo != null &&
        (photo.isEmpty || photo.length > 500000 || body != null)) {
      _active.remove(abort);
      throw const ApiFailure(ApiFailureKind.payloadTooLarge);
    }
    final http.BaseRequest request;
    final uri = origin.resolve(path).replace(queryParameters: query);
    if (photo != null) {
      request =
          http.AbortableMultipartRequest(method, uri, abortTrigger: trigger)
            ..files.add(
              http.MultipartFile.fromBytes(
                'photo',
                photo,
                filename: 'photo.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );
    } else {
      request = http.AbortableRequest(method, uri, abortTrigger: trigger);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        (request as http.Request).body = jsonEncode(body);
      }
    }
    request.followRedirects = false;
    request.headers.addAll({
      'Accept': 'application/json',
      'X-Request-ID': requestId,
    });
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (expectedStatus != null && response.statusCode != expectedStatus) {
          throw ApiFailure(
            ApiFailureKind.invalidResponse,
            statusCode: response.statusCode,
            requestId: diagnosticId,
          );
        }
        return body;
      }
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

String newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
