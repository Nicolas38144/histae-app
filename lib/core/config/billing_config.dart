import 'package:flutter/foundation.dart';

/// Public switch for native purchases. Provider credentials stay on the server.
class BillingConfig {
  const BillingConfig({this.enabled = false});
  static const keys = ['BILLING_ENABLED'];
  factory BillingConfig.fromValues(Map<String, String> values) {
    final value = values['BILLING_ENABLED'] ?? 'false';
    if (!['true', 'false'].contains(value)) {
      throw const FormatException('Invalid public billing configuration');
    }
    return BillingConfig(enabled: value == 'true');
  }
  final bool enabled;
  bool get available => allows(defaultTargetPlatform, web: kIsWeb);
  bool allows(TargetPlatform platform, {bool web = false}) =>
      enabled &&
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform);
}
