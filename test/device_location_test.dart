import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/discovery/data/device_location.dart';

class _Device extends GeolocatorPlatform {
  final started = Completer<void>();
  late final positions = StreamController<Position>(
    onCancel: () => cancellations++,
  );
  LocationPermission permission = LocationPermission.whileInUse;
  int serviceChecks = 0, permissionChecks = 0, cancellations = 0;
  LocationSettings? settings;

  void dispose() => unawaited(positions.close());

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceChecks++;
    return false;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    started.complete();
    return positions.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform previous;
  late _Device device;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    device = _Device();
    GeolocatorPlatform.instance = device;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    GeolocatorPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
    device.dispose();
  });

  test(
    'Android reaches native service activation and takes one fresh fix',
    () async {
      final locating = DeviceLocation().locate(RequestCancellation());
      await device.started.future;
      expect(device.serviceChecks, 0);
      final settings = device.settings! as AndroidSettings;
      expect(settings.forceLocationManager, isFalse);
      expect(settings.foregroundNotificationConfig, isNull);
      expect(settings.maxUpdateAge, Duration.zero);
      device.positions.add(
        Position(
          longitude: 2.35,
          latitude: 48.85,
          timestamp: DateTime.now().toUtc(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      final fix = await locating;
      expect(fix.freshAt(DateTime.now()), isTrue);
      expect(device.cancellations, 1);
    },
  );

  test('declining native activation returns a disabled issue and closes the stream', () async {
    final locating = DeviceLocation().locate(RequestCancellation());
    final failure = expectLater(
      locating,
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.issue,
          'issue',
          LocationIssue.disabled,
        ),
      ),
    );
    await device.started.future;
    device.positions.addError(const LocationServiceDisabledException());
    await failure;
    expect(device.cancellations, 1);
  });

  test('cancellation during native activation cancels acquisition', () async {
    final scope = RequestCancellation();
    final locating = DeviceLocation().locate(scope);
    final failure = expectLater(
      locating,
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.issue,
          'issue',
          LocationIssue.cancelled,
        ),
      ),
    );
    await device.started.future;
    scope.cancel();
    await failure;
    expect(device.cancellations, 1);
  });

  test(
    'Android cannot start service activation without location permission',
    () async {
      device.permission = LocationPermission.deniedForever;
      await expectLater(
        DeviceLocation().locate(RequestCancellation()),
        throwsA(
          isA<LocationFailure>().having(
            (e) => e.issue,
            'issue',
            LocationIssue.deniedForever,
          ),
        ),
      );
      expect(device.started.isCompleted, isFalse);
    },
  );

  test(
    'iOS keeps the settings fallback when device location is disabled',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(
        DeviceLocation().locate(RequestCancellation()),
        throwsA(
          isA<LocationFailure>().having(
            (e) => e.issue,
            'issue',
            LocationIssue.disabled,
          ),
        ),
      );
      expect(device.serviceChecks, 1);
      expect(device.permissionChecks, 0);
      expect(device.started.isCompleted, isFalse);
    },
  );
}
