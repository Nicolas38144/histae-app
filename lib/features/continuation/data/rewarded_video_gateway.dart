import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import 'continuation_models.dart';

enum VideoFailure { consent, noFill, network, load, show, expired }

class RewardedVideoException implements Exception {
  const RewardedVideoException(this.reason);
  final VideoFailure reason;
}

/// Native playback has no authority to award credits. Only the API does.
abstract interface class RewardedVideoGateway {
  String? get platform;
  String? get unavailableReason;
  bool get privacyOptionsRequired;
  Future<void> requestConsent(bool Function() isCurrent);
  Future<void> showPrivacyOptions();
  Future<PreparedRewardedVideo> load(RewardIntent intent);
}

abstract interface class PreparedRewardedVideo {
  /// Completes on dismissal, reporting only the SDK's completion signal.
  Future<bool> show();
  Future<void> dispose();
}

class AdmobRewardedVideoGateway implements RewardedVideoGateway {
  AdmobRewardedVideoGateway(this.config);
  final AppConfig config;
  Future<void>? _initialization;
  bool _consentChecked = false;
  @override
  bool privacyOptionsRequired = false;
  @override
  String? get platform => kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => null,
        };
  @override
  String? get unavailableReason {
    if (platform == null) {
      return 'Les vidéos sont disponibles sur Android et iOS.';
    }
    final id = platform == 'android'
        ? config.admobAndroidAppId
        : config.admobIosAppId;
    return id == null
        ? 'Les vidéos ne sont pas encore configurées pour cet appareil.'
        : null;
  }

  @override
  Future<void> requestConsent(bool Function() isCurrent) async {
    _consentChecked = false;
    // Refresh UMP on each explicit watch request, before any advertising request.
    // Histae's own consent records do not replace Google's privacy choices.
    final updated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(true),
      (_) => updated.complete(false),
    );
    final success = await updated.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
    if (!isCurrent()) return;
    if (!success) throw const RewardedVideoException(VideoFailure.consent);
    privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!isCurrent()) return;
    FormError? formError;
    await ConsentForm.loadAndShowConsentFormIfRequired((e) => formError = e);
    if (!isCurrent()) return;
    if (formError != null ||
        !await ConsentInformation.instance.canRequestAds()) {
      throw const RewardedVideoException(VideoFailure.consent);
    }
    _consentChecked = isCurrent();
  }

  @override
  Future<void> showPrivacyOptions() async {
    _consentChecked = false;
    FormError? error;
    await ConsentForm.showPrivacyOptionsForm((e) => error = e);
    if (error != null) throw const RewardedVideoException(VideoFailure.consent);
  }

  Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<PreparedRewardedVideo> load(RewardIntent intent) async {
    if (!_consentChecked ||
        !await ConsentInformation.instance.canRequestAds()) {
      throw const RewardedVideoException(VideoFailure.consent);
    }
    await (_initialization ??= _initialize()).timeout(
      const Duration(seconds: 40),
    );
    final result = Completer<RewardedAd>();
    var abandoned = false;
    try {
      unawaited(
        RewardedAd.load(
          // Both values come from the same authenticated server intent. No
          // fallback unit, personal user ID, or client-generated proof is sent.
          adUnitId: intent.adUnit,
          request: const AdRequest(nonPersonalizedAds: true),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              if (abandoned) {
                unawaited(ad.dispose());
              } else {
                result.complete(ad);
              }
            },
            onAdFailedToLoad: (e) {
              if (!abandoned) {
                result.completeError(
                  RewardedVideoException(switch (e.code) {
                    2 => VideoFailure.network,
                    3 => VideoFailure.noFill,
                    _ => VideoFailure.load,
                  }),
                );
              }
            },
          ),
        ).catchError((Object error) {
          if (!abandoned && !result.isCompleted) result.completeError(error);
        }),
      );
      final ad = await result.future.timeout(const Duration(seconds: 45));
      try {
        await ad
            .setServerSideOptions(
              ServerSideVerificationOptions(customData: intent.customData),
            )
            .timeout(const Duration(seconds: 10));
        return _AdmobVideo(ad);
      } catch (_) {
        await ad.dispose();
        rethrow;
      }
    } finally {
      abandoned = true;
    }
  }
}

class _AdmobVideo implements PreparedRewardedVideo {
  _AdmobVideo(this.ad);
  final RewardedAd ad;
  bool _disposed = false;
  @override
  Future<bool> show() async {
    final closed = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) {
        if (!closed.isCompleted) closed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (_, _) {
        if (!closed.isCompleted) {
          closed.completeError(const RewardedVideoException(VideoFailure.show));
        }
      },
    );
    unawaited(
      ad.show(onUserEarnedReward: (_, _) => earned = true).catchError((
        Object error,
      ) {
        if (!closed.isCompleted) closed.completeError(error);
      }),
    );
    return closed.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await ad.dispose();
  }
}
