import 'package:url_launcher/url_launcher.dart';

import 'billing_models.dart';

abstract interface class BillingGateway {
  Future<bool> open(Uri url, {required bool portal});
}

class ExternalBillingGateway implements BillingGateway {
  @override
  Future<bool> open(Uri url, {required bool portal}) async {
    try {
      stripeUrl(url.toString(), portal: portal);
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
