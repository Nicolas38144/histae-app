import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The plugin's own codecs let this boundary test exercise the real adapter
// without loading an ad or making a Google request.
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/features/continuation/data/continuation_models.dart';
import 'package:histae_app/features/continuation/data/rewarded_video_gateway.dart';

import 'support/continuation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('UMP configuration and network errors stay distinct; only SDK-confirmed cached consent permits recovery', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final ump = MethodChannel(
      'plugins.flutter.io/google_mobile_ads/ump',
      StandardMethodCodec(UserMessagingCodec()),
    );
    var allowed = false, code = '3', forms = 0;
    messenger.setMockMethodCallHandler(ump, (call) async {
      if (call.method == 'ConsentInformation#requestConsentInfoUpdate') {
        throw PlatformException(
          code: code,
          message: code == '3'
              ? 'Publisher misconfiguration: no form(s) configured for the input app ID.'
              : 'Network error',
        );
      }
      if (call.method == 'ConsentInformation#canRequestAds') return allowed;
      if (call.method ==
          'ConsentInformation#getPrivacyOptionsRequirementStatus') {
        return 1;
      }
      if (call.method ==
          'UserMessagingPlatform#loadAndShowConsentFormIfRequired') {
        forms++;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(ump, null));
    final gateway = AdmobRewardedVideoGateway(
      AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'https://api.example',
        isDebug: false,
        admobAndroidAppId: 'ca-app-pub-3940256099942544~3347511713',
      ),
    );
    await expectLater(
      gateway.requestConsent(() => true),
      throwsA(
        isA<RewardedVideoException>().having(
          (e) => e.reason,
          'reason',
          VideoFailure.consentConfiguration,
        ),
      ),
    );
    await expectLater(
      gateway.load(RewardIntent.fromJson(rewardJson())),
      throwsA(isA<RewardedVideoException>()),
    );
    code = '2';
    await expectLater(
      gateway.requestConsent(() => true),
      throwsA(
        isA<RewardedVideoException>().having(
          (e) => e.reason,
          'reason',
          VideoFailure.consentNetwork,
        ),
      ),
    );
    allowed = true;
    await gateway.requestConsent(() => true);
    expect(gateway.privacyOptionsRequired, isTrue);
    expect(forms, 0);
  });
  test('real AdMob adapter waits for UMP and attaches the API custom data before native display', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final ads = instanceManager.channel;
    final ump = MethodChannel(
      'plugins.flutter.io/google_mobile_ads/ump',
      StandardMethodCodec(UserMessagingCodec()),
    );
    final events = <String>[];
    var consentAllowed = false;
    Future<void> emit(
      int id,
      String name, [
      Map<String, Object?> extra = const {},
    ]) async {
      await messenger.handlePlatformMessage(
        ads.name,
        ads.codec.encodeMethodCall(
          MethodCall('onAdEvent', {'adId': id, 'eventName': name, ...extra}),
        ),
        (_) {},
      );
    }

    messenger.setMockMethodCallHandler(ump, (call) async {
      events.add(call.method);
      return switch (call.method) {
        'ConsentInformation#canRequestAds' => consentAllowed,
        'ConsentInformation#getPrivacyOptionsRequirementStatus' => 1,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(ads, (call) async {
      events.add(call.method);
      final args = call.arguments as Map<dynamic, dynamic>?;
      switch (call.method) {
        case 'MobileAds#initialize':
          return InitializationStatus({});
        case 'loadRewardedAd':
          expect(args!['adUnitId'], rewardJson()['ad_unit']);
          expect((args['request'] as AdRequest).nonPersonalizedAds, isTrue);
          await emit(args['adId'] as int, 'onAdLoaded');
        case 'setServerSideVerificationOptions':
          final options =
              args!['serverSideVerificationOptions']
                  as ServerSideVerificationOptions;
          expect(options.customData, rewardId);
          expect(options.userId, isNull);
        case 'showAdWithoutView':
          final id = args!['adId'] as int;
          await emit(id, 'onRewardedAdUserEarnedReward', {
            'rewardItem': RewardItem(1, 'continuation_credit'),
          });
          await emit(id, 'onAdDismissedFullScreenContent');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(ump, null);
      messenger.setMockMethodCallHandler(ads, null);
    });
    final gateway = AdmobRewardedVideoGateway(
      AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'https://api.example',
        isDebug: false,
        admobAndroidAppId: 'ca-app-pub-3940256099942544~3347511713',
      ),
    );
    await expectLater(
      gateway.load(RewardIntent.fromJson(rewardJson())),
      throwsA(isA<RewardedVideoException>()),
    );
    await expectLater(
      gateway.requestConsent(() => true),
      throwsA(isA<RewardedVideoException>()),
    );
    expect(events, isNot(contains('MobileAds#initialize')));
    consentAllowed = true;
    await gateway.requestConsent(() => true);
    expect(gateway.privacyOptionsRequired, isTrue);
    final video = await gateway.load(RewardIntent.fromJson(rewardJson()));
    expect(await video.show(), isTrue);
    await video.dispose();
    expect(
      events.indexOf('ConsentInformation#canRequestAds'),
      lessThan(events.indexOf('loadRewardedAd')),
    );
    expect(
      events.indexOf('setServerSideVerificationOptions'),
      lessThan(events.indexOf('showAdWithoutView')),
    );
    expect(events.last, 'disposeAd');
  });
}
