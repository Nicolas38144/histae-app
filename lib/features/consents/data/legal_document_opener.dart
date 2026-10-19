import 'package:url_launcher/url_launcher.dart';

typedef DocumentOpener = Future<bool> Function(Uri url);

Future<bool> openLegalDocument(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
    return false;
  }
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
