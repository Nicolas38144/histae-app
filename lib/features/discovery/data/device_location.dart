import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';

enum LocationIssue {
  disabled,
  denied,
  deniedForever,
  timeout,
  stale,
  unavailable,
  cancelled,
}

class LocationFailure implements Exception {
  const LocationFailure(this.issue);
  final LocationIssue issue;

  @override
  String toString() => 'LocationFailure(${issue.name})';
}

class LocationFix {
  const LocationFix(
    this.latitude,
    this.longitude,
    this.observedAt, {
    this.approximate = false,
  });
  final double latitude, longitude;
  final DateTime observedAt;
  final bool approximate;

  bool freshAt(DateTime now) {
    final age = now.toUtc().difference(observedAt.toUtc());
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180 &&
        age >= const Duration(seconds: -30) &&
        age <= const Duration(minutes: 2);
  }

  @override
  String toString() => 'LocationFix(redacted)';
}

abstract class LocationSource {
  Future<LocationFix> locate(RequestCancellation cancellation);

  Future<bool> openSettings({required bool services});
}

class DeviceLocation implements LocationSource {
  void _check(RequestCancellation scope) {
    if (scope.isCancelled) throw const LocationFailure(LocationIssue.cancelled);
  }

  @override
  Future<LocationFix> locate(RequestCancellation cancellation) async {
    StreamSubscription<Position>? subscription;
    try {
      _check(cancellation);
      final android =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      // Android's fused provider resolves disabled services through its native
      // activation dialog when the stream starts. An early rejection bypasses it.
      if (!android && !await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationIssue.disabled);
      }
      _check(cancellation);
      var permission = await Geolocator.checkPermission();
      _check(cancellation);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _check(cancellation);
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(LocationIssue.deniedForever);
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const LocationFailure(LocationIssue.denied);
      }
      final accuracy = await Geolocator.getLocationAccuracy();
      _check(cancellation);
      final LocationSettings settings = android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              maxUpdateAge: Duration.zero,
              timeLimit: const Duration(seconds: 25),
            )
          : defaultTargetPlatform == TargetPlatform.iOS
          ? AppleSettings(
              accuracy: LocationAccuracy.high,
              allowBackgroundLocationUpdates: false,
              pauseLocationUpdatesAutomatically: true,
              timeLimit: const Duration(seconds: 25),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 25),
            );
      final first = Completer<Position>();
      subscription = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (position) {
              if (!first.isCompleted) first.complete(position);
            },
            onError: (Object error) {
              if (!first.isCompleted) first.completeError(error);
            },
          );
      // One fix only. Cancellation stops the native subscription on leave,
      // backgrounding, consent changes or logout. No last-known location.
      final position = await Future.any<Position>([
        first.future,
        cancellation.whenCancelled.then<Position>(
          (_) => throw const LocationFailure(LocationIssue.cancelled),
        ),
      ]).timeout(const Duration(seconds: 25));
      _check(cancellation);
      final fix = LocationFix(
        position.latitude,
        position.longitude,
        position.timestamp,
        approximate: accuracy == LocationAccuracyStatus.reduced,
      );
      if (!fix.freshAt(DateTime.now())) {
        throw const LocationFailure(LocationIssue.stale);
      }
      return fix;
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(LocationIssue.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationIssue.disabled);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationIssue.denied);
    } catch (_) {
      throw const LocationFailure(LocationIssue.unavailable);
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  Future<bool> openSettings({required bool services}) async {
    try {
      return services
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
