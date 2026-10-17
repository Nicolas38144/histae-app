import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/config/push_config.dart';
import 'notification_models.dart';

enum PushPermission {
  notDetermined,
  denied,
  authorized,
  provisional,
  unavailable,
}

abstract interface class PushGateway {
  bool get configured;
  String get platform;
  Future<void> initialize();
  Future<PushPermission> permission({bool request = false});
  Future<String> registration();
  Future<void> disable();
  Stream<String> get registrations;
  Stream<PushIntent> get received;
  Stream<PushIntent> get opened;
  Future<PushIntent?> initial();
}

// The OS handles the server's generic background notification. This handler
// never fetches private resources, touches a session, logs, or navigates.
@pragma('vm:entry-point')
Future<void> histaeBackgroundPush(RemoteMessage message) async {}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway(this.config);
  final PushConfig config;
  FirebaseMessaging? _messaging;
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  bool get configured =>
      !kIsWeb &&
      config.enabled &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android => config.androidReady,
        TargetPlatform.iOS => config.iosReady,
        _ => false,
      };
  @override
  Future<void> initialize() async {
    if (!configured || _messaging != null) return;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: platform == 'ios' ? config.iosApiKey : config.androidApiKey,
        appId: platform == 'ios' ? config.iosAppId : config.androidAppId,
        messagingSenderId: config.senderId,
        projectId: config.projectId,
        iosBundleId: platform == 'ios' ? config.iosBundleId : null,
      ),
    );
    _messaging = FirebaseMessaging.instance;
    await _messaging!.setAutoInitEnabled(false);
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    FirebaseMessaging.onBackgroundMessage(histaeBackgroundPush);
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    final m = _messaging;
    if (m == null) return PushPermission.unavailable;
    final settings = request
        ? await m.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
        : await m.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<String> registration() async {
    final m = _messaging;
    if (m == null) throw StateError('Push unavailable');
    if (platform == 'ios') {
      await const MethodChannel('histae/push')
          .invokeMethod<void>('registerAPNs');
      var available = false;
      for (var attempt = 0; attempt < 30; attempt++) {
        if (await m.getAPNSToken() != null) {
          available = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!available) throw StateError('APNs not ready');
    }
    final result = Completer<String>();
    final subscription = m.onRegistered.listen(
      (id) {
        if (!result.isCompleted) result.complete(id);
      },
      onError: (Object _, StackTrace _) {
        if (!result.isCompleted) {
          result.completeError(StateError('Push unavailable'));
        }
      },
    );
    try {
      final values = await Future.wait<Object?>([
        m.register().timeout(const Duration(seconds: 20)),
        result.future.timeout(const Duration(seconds: 20)),
      ]);
      return values.last as String;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> disable() async {
    final m = _messaging;
    if (m != null) {
      await m.setAutoInitEnabled(false);
      await m.unregister().timeout(const Duration(seconds: 20));
    }
  }

  @override
  Stream<String> get registrations =>
      _messaging?.onRegistered ?? const Stream.empty();
  Stream<PushIntent> _map(Stream<RemoteMessage> stream) => stream
      .map((m) => PushIntent.parse(m.data))
      .where((i) => i != null)
      .cast<PushIntent>();
  @override
  Stream<PushIntent> get received => _map(FirebaseMessaging.onMessage);
  @override
  Stream<PushIntent> get opened => _map(FirebaseMessaging.onMessageOpenedApp);
  @override
  Future<PushIntent?> initial() async {
    final message = await _messaging?.getInitialMessage();
    return message == null ? null : PushIntent.parse(message.data);
  }
}
