enum ApiFailureKind {
  network,
  timeout,
  cancelled,
  invalidResponse,
  validation,
  unauthenticated,
  forbidden,
  consentRequired,
  discoveryNotReady,
  quota,
  notFound,
  conflict,
  expired,
  payloadTooLarge,
  rateLimited,
  unavailable,
  server,
  unexpected,
  secureStorage,
  sessionUncertain,
}

class ApiFailure implements Exception {
  const ApiFailure(
    this.kind, {
    this.statusCode,
    this.code,
    this.requestId,
    this.retryAt,
  });
  final ApiFailureKind kind;
  final int? statusCode;
  final String? code;
  final String? requestId;
  final DateTime? retryAt;

  static ApiFailureKind classify(int status, String? code) {
    if (status == 409 && code == 'discovery_not_ready') {
      return ApiFailureKind.discoveryNotReady;
    }
    if (status == 403) {
      if (code == 'onboarding_incomplete' ||
          code == 'required_consent_missing') {
        return ApiFailureKind.consentRequired;
      }
      if (code == 'continuation_quota_reached') {
        return ApiFailureKind.quota;
      }
    }
    return switch (status) {
      400 || 422 => ApiFailureKind.validation,
      401 => ApiFailureKind.unauthenticated,
      403 => ApiFailureKind.forbidden,
      404 => ApiFailureKind.notFound,
      409 => ApiFailureKind.conflict,
      410 => ApiFailureKind.expired,
      413 => ApiFailureKind.payloadTooLarge,
      429 => ApiFailureKind.rateLimited,
      503 => ApiFailureKind.unavailable,
      >= 500 => ApiFailureKind.server,
      _ => ApiFailureKind.unexpected,
    };
  }
  // Never include response bodies, URLs, headers or server messages in logs.

  @override
  String toString() => 'ApiFailure(${kind.name}, status: $statusCode)';
}
