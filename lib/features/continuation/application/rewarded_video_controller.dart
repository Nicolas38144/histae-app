import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/continuation_models.dart';
import '../data/rewarded_video_gateway.dart';
import 'continuation_controller.dart';

enum VideoPhase { idle, checking, consent, loading, playing, privacy }

/// Owns one explicit viewing attempt and discards callbacks after leaving its
/// page/session. A completed video only starts server verification.
class RewardedVideoController extends ChangeNotifier {
  RewardedVideoController(this.credits, this.gateway) {
    _key = credits.access.session.resourceKey;
    _privacy = credits.access.privacyEpoch;
    credits.addListener(_changed);
  }
  final ContinuationController credits;
  final RewardedVideoGateway? gateway;
  late final String _key;
  late int _privacy;
  bool _disposed = false, _active = true, foreground = true;
  int _epoch = 0;
  VideoPhase phase = VideoPhase.idle;
  String? message;
  bool get busy => phase != VideoPhase.idle;
  bool get nativeOverlay => switch (phase) {
    VideoPhase.consent || VideoPhase.playing || VideoPhase.privacy => true,
    _ => false,
  };
  bool get _owner =>
      !_disposed &&
      _active &&
      credits.active &&
      credits.access.session.resourceKey == _key &&
      credits.access.privacyEpoch == _privacy;
  bool _alive(int epoch) => _owner && epoch == _epoch;
  String? get unavailableReason {
    final q = credits.quota;
    if (!_owner ||
        credits.loading ||
        q == null ||
        credits.quotaReadAt == null) {
      return 'Actualisez votre solde pour accéder aux vidéos.';
    }
    if (q.premium) return 'Premium vous permet de continuer sans crédit.';
    if (credits.catalogFailure != null) {
      return 'La disponibilité des vidéos n’a pas pu être vérifiée.';
    }
    if (!credits.advertisingEnabled) {
      return 'Les vidéos sont momentanément désactivées pour votre formule.';
    }
    if (q.advertisingBalance >= q.stockLimit) {
      return 'Votre réserve vidéo est pleine. Utilisez un crédit pour libérer une place.';
    }
    if (gateway == null) {
      return 'Les vidéos ne sont pas configurées pour cette version.';
    }
    return gateway!.unavailableReason;
  }

  bool get canWatch {
    final r = credits.rewards, i = r.intent;
    return !busy &&
        foreground &&
        unavailableReason == null &&
        !r.busy &&
        !r.waiting &&
        !(i?.status == RewardStatus.pending && r.completedVideo) &&
        i?.status != RewardStatus.expired;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (_privacy != credits.access.privacyEpoch) {
      _privacy = credits.access.privacyEpoch;
      _epoch++;
    }
    if (!_owner || credits.quota?.premium == true) _epoch++;
  }

  void suspend() {
    _active = false;
    _epoch++;
  }

  void resume() {
    if (!_disposed) _active = true;
  }

  void _phase(VideoPhase value) {
    phase = value;
    _notify();
  }

  Future<void> watch() async {
    if (!canWatch) return;
    final epoch = ++_epoch, r = credits.rewards;
    PreparedRewardedVideo? video;
    String? preparedId;
    var shown = false;
    message = null;
    _phase(VideoPhase.checking);
    try {
      await credits.loadQuota();
      if (!_alive(epoch) || unavailableReason != null) return;
      _phase(VideoPhase.consent);
      await gateway!.requestConsent(() => _alive(epoch) && foreground);
      if (!_alive(epoch) || !foreground) return;
      // A formula or stock may have changed while the native form was open.
      _phase(VideoPhase.checking);
      await credits.loadQuota();
      if (!_alive(epoch) || unavailableReason != null) return;
      if (r.canPoll) await r.refresh();
      if (!_alive(epoch) || r.busy || r.waiting) return;
      var intent = r.intent;
      if (intent?.status == RewardStatus.expired ||
          (intent?.status == RewardStatus.pending && r.completedVideo)) {
        return;
      }
      if (intent?.status != RewardStatus.pending) {
        intent = await r.prepare(gateway!.platform!);
      }
      if (!_alive(epoch) || intent == null) return;
      preparedId = intent.id;
      if (!intent.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const RewardedVideoException(VideoFailure.expired);
      }
      _phase(VideoPhase.loading);
      video = await gateway!.load(intent);
      if (!_alive(epoch) || !foreground) return;
      await credits.loadQuota();
      if (!_alive(epoch) ||
          unavailableReason != null ||
          r.intent?.status != RewardStatus.pending) {
        return;
      }
      if (!intent.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const RewardedVideoException(VideoFailure.expired);
      }
      _phase(VideoPhase.playing);
      shown = true;
      final earned = await video.show();
      if (!_alive(epoch)) return;
      _phase(VideoPhase.checking);
      if (earned) {
        await r.videoCompleted();
      } else {
        message = 'La vidéo a été fermée avant la fin. Vous pouvez réessayer.';
        await r.cancel();
      }
    } on RewardedVideoException catch (e) {
      if (_alive(epoch)) {
        message = switch (e.reason) {
          VideoFailure.consent => 'Vos préférences publicitaires n’ont pas pu être vérifiées. Réessayez ou consultez vos choix de confidentialité.',
          VideoFailure.noFill => 'Aucune vidéo disponible pour le moment. Réessayez un peu plus tard.',
          VideoFailure.network =>
            'La vidéo n’a pas pu être chargée. Vérifiez votre connexion.',
          VideoFailure.expired => 'Cette demande a expiré. Annulez-la avant de regarder une nouvelle vidéo.',
          VideoFailure.load =>
            'La vidéo n’a pas pu être chargée. Réessayez plus tard.',
          VideoFailure.show =>
            'La vidéo n’a pas pu être affichée. Vous pouvez réessayer.',
        };
      }
    } catch (_) {
      if (_alive(epoch)) {
        message =
            'La vidéo est momentanément indisponible. Vous pouvez réessayer.';
      }
    } finally {
      // Release a known unplayed attempt. A displayed video with an uncertain
      // outcome stays available for a late signed proof.
      if (!shown &&
          preparedId != null &&
          _alive(epoch) &&
          r.intent?.id == preparedId &&
          !r.completedVideo) {
        await r.cancel();
      }
      // A native cleanup failure must not strand the screen in a busy state.
      try {
        await video?.dispose();
      } catch (_) {
        /* Best effort after playback. */
      }
      _finish();
    }
  }

  Future<void> privacyOptions() async {
    if (!_owner || busy || gateway?.privacyOptionsRequired != true) return;
    final epoch = ++_epoch;
    message = null;
    _phase(VideoPhase.privacy);
    try {
      await gateway!.showPrivacyOptions();
    } catch (_) {
      if (_alive(epoch)) {
        message = 'Vos préférences ne sont pas accessibles pour le moment.';
      }
    } finally {
      _finish();
    }
  }

  void _finish() {
    if (_disposed) return;
    if (_owner && !foreground) {
      suspend();
      credits.suspend();
    }
    _phase(VideoPhase.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    credits.removeListener(_changed);
    super.dispose();
  }
}
