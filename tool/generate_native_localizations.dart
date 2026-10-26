// Run from the project root after editing native iOS copy in the ARBs.
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
  }
}
