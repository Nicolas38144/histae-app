import 'package:url_launcher/url_launcher.dart';

typedef DocumentOpener = Future<bool> Function(Uri url);

final _legacyHistaeLegalPath = RegExp(r'^/(fr|en|es|it)/legal/([^/]+)/?$');
const _publishedSlugs = {
  'conditions-utilisation': 'terms-of-use',
  'politique-confidentialite': 'privacy-policy',
  'consentement-donnees-sensibles': 'sensitive-data-consent',
  'consentement-localisation': 'location-consent',
};

/// Fixes legacy paths for navigation without changing the API's consent metadata.
Uri canonicalHistaeLegalUrl(Uri url) {
  if (url.scheme != 'https' ||
      url.host != 'www.histae.com' ||
      url.port != 443 ||
      url.userInfo.isNotEmpty) {
    return url;
  }
  final match = _legacyHistaeLegalPath.firstMatch(url.path);
  if (match == null) return url;
  final slug = _publishedSlugs[match[2]];
  return slug == null ? url : url.replace(path: '/${match[1]}/legal/$slug/');
}

Future<bool> openLegalDocument(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
    return false;
  }
  try {
    return await launchUrl(
      canonicalHistaeLegalUrl(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
