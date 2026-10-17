import 'package:flutter/foundation.dart';

/// Public deployment settings. Enabling this gate is only appropriate for the
/// separately distributed Android build; it is not a remote API feature flag.
class BillingConfig {
  const BillingConfig({
    this.enabled = false,
    this.distribution = 'disabled',
    this.successUrl,
    this.cancelUrl,
    this.portalReturnUrl,
  });
  static const keys = [
    'BILLING_ENABLED',
    'BILLING_DISTRIBUTION',
    'BILLING_SUCCESS_URL',
    'BILLING_CANCEL_URL',
    'BILLING_PORTAL_RETURN_URL',
  ];
  factory BillingConfig.fromValues(Map<String, String> values) {
    final flag = values['BILLING_ENABLED'] ?? 'false';
    final distribution = values['BILLING_DISTRIBUTION'] ?? 'disabled';
    if (!['true', 'false'].contains(flag) ||
        !['disabled', 'android_external'].contains(distribution)) {
      throw const FormatException('Invalid public billing configuration');
    }
    Uri? link(String key) {
      final raw = values[key] ?? '';
      if (raw.isEmpty) return null;
      final url = Uri.tryParse(raw);
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          (url.hasPort && url.port != 443)) {
        throw const FormatException('Invalid public billing return URL');
      }
      return url;
    }

    final success = link('BILLING_SUCCESS_URL');
    final cancel = link('BILLING_CANCEL_URL');
    final portal = link('BILLING_PORTAL_RETURN_URL');
    if (flag == 'true' &&
        (distribution != 'android_external' ||
            success == null ||
            cancel == null ||
            portal == null ||
            !(values['BILLING_SUCCESS_URL'] ?? '').contains(
              '{CHECKOUT_SESSION_ID}',
            ))) {
      throw const FormatException('Incomplete public billing configuration');
    }
    return BillingConfig(
      enabled: flag == 'true',
      distribution: distribution,
      successUrl: success,
      cancelUrl: cancel,
      portalReturnUrl: portal,
    );
  }
  final bool enabled;
  final String distribution;
  final Uri? successUrl, cancelUrl, portalReturnUrl;
  bool get available => allows(defaultTargetPlatform, web: kIsWeb);
  bool allows(TargetPlatform platform, {bool web = false}) =>
      !web &&
      platform == TargetPlatform.android &&
      enabled &&
      distribution == 'android_external' &&
      successUrl != null &&
      cancelUrl != null &&
      portalReturnUrl != null;
}
