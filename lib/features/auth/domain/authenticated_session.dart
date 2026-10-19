import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../consents/domain/consent_state.dart';
import 'auth_models.dart';

enum SessionPhase {
  restoring,
  signedOut,
  synchronizing,
  needsConsents,
  ready,
  unavailable,
  storageFailure,
}

/// Contract shared by feature repositories and controllers. Consumers neither
/// own tokens nor depend on the authentication controller's implementation.
abstract interface class AuthenticatedSession implements Listenable {
  Uri get apiOrigin;

  SessionPhase get phase;

  MobileIdentity? get identity;

  ConsentState? get consents;

  String get resourceKey;

  bool get hasSession;

  bool get isSynchronizing;

  int get retrySeconds;

  Future<void> synchronize();

  Future<void> saveConsents(
    Map<ConsentType, bool> changes,
    Map<ConsentType, String> displayedVersions,
  );

  Future<void> logout();

  Future<void> eraseAccount(String confirmationToken);

  Future<void> logoutEverywhere();

  Future<void> revokeCurrentSession(String id);

  Future<Object?> publicJson(String path, {RequestCancellation? cancellation});

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    List<int>? photo,
    String? idempotencyKey,
    required int expectedStatus,
    required bool replayAfterRefresh,
    RequestCancellation? cancellation,
  });

  Future<ApiEventStream> openEvents(RequestCancellation cancellation);

  Future<ApiDownload> openDataExport(RequestCancellation cancellation);
}
