import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<bool> openNotificationSystemSettings() async {
  if (kIsWeb) return false;
  final channel = switch (defaultTargetPlatform) {
    TargetPlatform.android => const MethodChannel('histae/notifications'),
    TargetPlatform.iOS => const MethodChannel('histae/push'),
    _ => null,
  };
  if (channel == null) return false;
  try {
    return await channel.invokeMethod<bool>('openNotificationSettings') == true;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
