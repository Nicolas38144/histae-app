import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'storefront_regions.dart';

class StoreUpdate {
  const StoreUpdate(this.storeUri);
  final Uri storeUri;
}

abstract interface class StoreUpdateGateway {
  Future<StoreUpdate?> check();
  Future<bool> open(StoreUpdate update);
  void dispose();
}

/// Public store metadata only; no Histae token, account, device ID or persistence.
class NativeStoreUpdateGateway implements StoreUpdateGateway {
  NativeStoreUpdateGateway({http.Client? client})
    : _client = client ?? http.Client();
  static const channel = MethodChannel('histae/store-updates');
  final http.Client _client;

  @override
  Future<StoreUpdate?> check() async {
    if (kIsWeb || !kReleaseMode) return null;
    final context = await channel.invokeMapMethod<String, dynamic>('check');
    if (context == null) return null;
    if (context['platform'] == 'android') {
      final package = context['package'];
      if (context['available'] != true ||
          package is! String ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$')
              .hasMatch(package)) {
        return null;
      }
      return StoreUpdate(
        Uri.https('play.google.com', '/store/apps/details', {'id': package}),
      );
    }
    if (context['platform'] != 'ios') return null;
    return lookupAppleUpdate(context, _client);
  }

  @override
  Future<bool> open(StoreUpdate update) async {
    final uri = update.storeUri;
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !{'play.google.com', 'apps.apple.com'}.contains(uri.host)) {
      return false;
    }
    if (uri.host == 'play.google.com') {
      final package = uri.queryParameters['id'];
      if (package == null) return false;
      try {
        if (await launchUrl(
          Uri(
            scheme: 'market',
            host: 'details',
            queryParameters: {'id': package},
          ),
          mode: LaunchMode.externalApplication,
        )) {
          return true;
        }
      } catch (_) {
        // The verified HTTPS page is the fallback when the market intent fails.
      }
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() => _client.close();
}

/// A regional public listing must match this app and be compatible with this OS.
Future<StoreUpdate?> lookupAppleUpdate(
  Map<String, dynamic> context,
  http.Client client,
) async {
  final bundle = context['bundle'];
  final country = storefrontCountries[context['country']];
  final installed = context['version'], os = context['os'];
  if (bundle is! String ||
      country is! String ||
      installed is! String ||
      os is! String ||
      !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
    return null;
  }
  final response = await client
      .get(
        Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': bundle,
          'country': country,
          'entity': 'software',
        }),
        headers: {'Accept': 'application/json'},
      )
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200 || response.bodyBytes.length > 1024 * 1024) {
    throw StateError('Store metadata unavailable');
  }
  final body = jsonDecode(utf8.decode(response.bodyBytes));
  if (body is! Map ||
      body['resultCount'] != 1 ||
      body['results'] is! List ||
      (body['results'] as List).length != 1) {
    return null;
  }
  final item = (body['results'] as List).single;
  if (item is! Map ||
      item['bundleId'] != bundle ||
      item['kind'] != 'software' ||
      item['trackId'] is! int ||
      (item['trackId'] as int) <= 0 ||
      item['version'] is! String ||
      item['minimumOsVersion'] is! String) {
    return null;
  }
  final newer = compareStoreVersions(item['version'] as String, installed);
  final compatible = compareStoreVersions(
    os,
    item['minimumOsVersion'] as String,
  );
  if (newer == null || newer <= 0 || compatible == null || compatible < 0) {
    return null;
  }
  return StoreUpdate(
    Uri.https(
      'apps.apple.com',
      '/${country.toLowerCase()}/app/id${item['trackId']}',
    ),
  );
}

int? compareStoreVersions(String left, String right) {
  if (!RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(left) ||
      !RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(right)) {
    return null;
  }
  final a = left.split('.').map(int.parse).toList();
  final b = right.split('.').map(int.parse).toList();
  for (var i = 0; i < a.length || i < b.length; i++) {
    final result = (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
    if (result != 0) return result;
  }
  return 0;
}
