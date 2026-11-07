// Run from the project root after editing native copy or channel names in the ARBs.
import 'dart:convert';
import 'dart:io';

void main() {
  const keys = {
    'NSLocationWhenInUseUsageDescription': 'iosLocationPermission',
    'NSPhotoLibraryUsageDescription': 'iosPhotoPermission',
    'NSCameraUsageDescription': 'iosCameraPermission',
    'NSLocalNetworkUsageDescription': 'iosLocalNetworkPermission',
    'HistaePrivacyShieldTitle': 'screenPrivacyLabel',
    'HistaePrivacyShieldCaptureHelp': 'screenCaptureHelp',
  };
  for (final locale in ['fr', 'en', 'es', 'it']) {
    final copy = jsonDecode(
      File('lib/core/l10n/arb/app_$locale.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final file = File('ios/Runner/$locale.lproj/InfoPlist.strings');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      [
        '// Generated from the ARB catalog. Do not edit by hand.',
        for (final entry in keys.entries)
          '${jsonEncode(entry.key)} = ${jsonEncode(copy[entry.value])};',
        '',
      ].join('\n'),
    );
    const channels = {
      'notification_messages': 'notificationMessages',
      'notification_matches': 'notificationNewMatches',
      'notification_continuations': 'notificationContinuations',
      'notification_photos': 'notificationPhotos',
      'notification_reminders': 'notificationReminders',
      'notification_account': 'notificationAccountSecurity',
    };
    final android = File(
      'android/app/src/main/res/values${locale == 'fr' ? '' : '-$locale'}/notification_channels.xml',
    );
    android.parent.createSync(recursive: true);
    String escaped(String value) =>
        const HtmlEscape(HtmlEscapeMode.element)
            .convert(value.replaceAll("'", "\\'").replaceAll('"', '\\"'));
    android.writeAsStringSync(
      [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<!-- Generated from the ARB catalog. Do not edit by hand. -->',
        '<resources>',
        for (final entry in channels.entries)
          '    <string name="${entry.key}" formatted="false">${escaped(copy[entry.value] as String)}</string>',
        '</resources>',
        '',
      ].join('\n'),
    );
  }
}
