import 'dart:async';

import 'package:histae_app/features/continuation/data/continuation_models.dart';
import 'package:histae_app/features/continuation/data/rewarded_video_gateway.dart';

import 'catalog_fixture.dart';

Map<String, dynamic> rewardedCatalogJson() {
  final json = catalogJson();
  final plans = json['plans'] as List<dynamic>;
  for (final value in plans) {
    final plan = value as Map<String, dynamic>;
    if (plan['code'] == 'free') plan['rewarded_advertising_enabled'] = true;
  }
  return json;
}

class FakeRewardedVideoGateway implements RewardedVideoGateway {
  @override
  String? platform = 'android';
  @override
  String? unavailableReason;
  @override
  bool privacyOptionsRequired = true;
  int consents = 0, privacyForms = 0;
  RewardedVideoException? consentFailure, loadFailure;
  Completer<void>? consentGate;
  Completer<PreparedRewardedVideo>? loadGate;
  final intents = <RewardIntent>[];
  FakePreparedVideo video = FakePreparedVideo();
  @override
  Future<void> requestConsent(bool Function() isCurrent) async {
    consents++;
    await consentGate?.future;
    if (consentFailure case final failure?) throw failure;
  }

  @override
  Future<void> showPrivacyOptions() async {
    privacyForms++;
  }

  @override
  Future<PreparedRewardedVideo> load(RewardIntent intent) async {
    intents.add(intent);
    if (loadFailure case final failure?) throw failure;
    return loadGate == null ? video : loadGate!.future;
  }
}

class FakePreparedVideo implements PreparedRewardedVideo {
  Completer<bool>? showGate;
  final shown = Completer<void>();
  bool earned = true;
  int shows = 0, disposals = 0;
  @override
  Future<bool> show() async {
    shows++;
    if (!shown.isCompleted) shown.complete();
    return showGate == null ? earned : showGate!.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
