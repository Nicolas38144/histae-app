class PushConfig {
  const PushConfig({
    this.enabled = false,
    this.projectId = '',
    this.senderId = '',
    this.androidApiKey = '',
    this.androidAppId = '',
    this.iosApiKey = '',
    this.iosAppId = '',
    this.iosBundleId = '',
  });

  factory PushConfig.fromValues(Map<String, String> values) {
    final flag = values['PUSH_ENABLED'] ?? 'false';
    if (!['true', 'false'].contains(flag)) {
      throw const FormatException('Invalid public push configuration');
    }
    String field(String key) {
      final v = values[key] ?? '';
      if (v.length > 255 || RegExp(r'\s').hasMatch(v)) {
        throw const FormatException('Invalid public push configuration');
      }
      return v;
    }

    final c = PushConfig(
      enabled: flag == 'true',
      projectId: field('FIREBASE_PROJECT_ID'),
      senderId: field('FIREBASE_MESSAGING_SENDER_ID'),
      androidApiKey: field('FIREBASE_ANDROID_API_KEY'),
      androidAppId: field('FIREBASE_ANDROID_APP_ID'),
      iosApiKey: field('FIREBASE_IOS_API_KEY'),
      iosAppId: field('FIREBASE_IOS_APP_ID'),
      iosBundleId: field('FIREBASE_IOS_BUNDLE_ID'),
    );
    for (final (id, platform) in [
      (c.androidAppId, 'android'),
      (c.iosAppId, 'ios'),
    ]) {
      if (id.isNotEmpty &&
          !RegExp('^1:[0-9]+:$platform:[a-fA-F0-9]+\$').hasMatch(id)) {
        throw const FormatException('Invalid public Firebase application ID');
      }
    }
    if (c.senderId.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(c.senderId)) {
      throw const FormatException('Invalid public Firebase sender ID');
    }
    if (c.projectId.isNotEmpty &&
        !RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(c.projectId)) {
      throw const FormatException('Invalid public Firebase project ID');
    }
    if (c.enabled && !c.androidReady && !c.iosReady) {
      throw const FormatException('Incomplete public push configuration');
    }
    for (final id in [c.androidAppId, c.iosAppId]) {
      if (id.isNotEmpty &&
          c.senderId.isNotEmpty &&
          id.split(':')[1] != c.senderId) {
        throw const FormatException('Inconsistent public Firebase sender ID');
      }
    }
    return c;
  }
  final bool enabled;
  final String projectId,
      senderId,
      androidApiKey,
      androidAppId,
      iosApiKey,
      iosAppId,
      iosBundleId;

  bool get androidReady => [
    projectId,
    senderId,
    androidApiKey,
    androidAppId,
  ].every((s) => s.isNotEmpty);

  bool get iosReady => [
    projectId,
    senderId,
    iosApiKey,
    iosAppId,
    iosBundleId,
  ].every((s) => s.isNotEmpty);
  static const keys = [
    'PUSH_ENABLED',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_ANDROID_API_KEY',
    'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_IOS_API_KEY',
    'FIREBASE_IOS_APP_ID',
    'FIREBASE_IOS_BUNDLE_ID',
  ];
}
