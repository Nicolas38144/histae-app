import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../data/continuation_models.dart';
import '../data/continuation_repository.dart';

// The native video/UMP SDK is deliberately disabled until application IDs and
// provider configuration are supplied. This tracks only server-owned rewards;
// a future SDK may call prepare/videoCompleted, never grant a local credit.
class RewardTracker extends ChangeNotifier {
  RewardTracker(this.repository, {required this.onCredited}) {
    _key = repository.session.resourceKey;
    repository.session.addListener(_sessionChanged);
  }
  final ContinuationRepository repository;
  final Future<void> Function() onCredited;
  late String _key;
  bool _disposed = false, _active = false;
  int _epoch = 0, _pollCount = 0;
  RequestCancellation _scope = RequestCancellation();
  Timer? _poll;
  String? _platform;
  RewardIntent? intent;
  ApiFailure? failure;
  bool busy = false, completedVideo = false, cancelled = false;
  DateTime? retryAt;
  bool get accessible =>
      !_disposed &&
      repository.session.hasSession &&
      repository.session.phase == SessionPhase.ready;
  bool get canPoll =>
      intent != null &&
      intent!.status != RewardStatus.credited &&
      intent!.status != RewardStatus.cancelled;
  bool get waiting => retryAt?.isAfter(DateTime.now()) == true;
  bool _alive(int epoch) => _active && accessible && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (accessible && _key == repository.session.resourceKey) return;
    _key = repository.session.resourceKey;
    suspend(notify: false);
    intent = null;
    _platform = null;
    failure = null;
    retryAt = null;
    completedVideo = false;
    cancelled = false;
    _notify();
  }

  void activate() {
    if (!accessible) return;
    if (!_active) {
      _active = true;
      _scope = RequestCancellation();
    }
    _pollCount = 0;
    if (canPoll) unawaited(refresh());
  }

  void suspend({bool notify = true}) {
    _active = false;
    _epoch++;
    _scope.cancel();
    _poll?.cancel();
    busy = false;
    if (notify) _notify();
  }

  Future<RewardIntent?> prepare(String platform) async {
    if (!_active ||
        !accessible ||
        busy ||
        waiting ||
        (intent != null && intent!.status != RewardStatus.cancelled) ||
        (_platform != null && _platform != platform)) {
      return null;
    }
    _platform = platform;
    cancelled = false;
    completedVideo = false;
    final epoch = _epoch;
    busy = true;
    failure = null;
    _notify();
    try {
      final result = await repository.createReward(platform, _scope);
      if (!_alive(epoch)) return null;
      intent = result;
      return result;
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        failure = e;
        retryAt = e.retryAt;
      }
      return null;
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  // A device callback records only that the video completed. Poll the signed
  // server result; expired can still become credited after a delayed proof.
  Future<void> videoCompleted() async {
    completedVideo = true;
    _notify();
    await refresh();
  }

  Future<void> refresh() async {
    final id = intent?.id;
    if (!_active || !accessible || id == null || busy || waiting) {
      if (_active && canPoll) _schedule();
      return;
    }
    final epoch = _epoch;
    busy = true;
    failure = null;
    _poll?.cancel();
    _notify();
    try {
      final result = await repository.reward(id, _scope);
      if (!_alive(epoch) || intent?.id != id) return;
      intent = result;
      if (result.status == RewardStatus.credited) await onCredited();
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        failure = e;
        retryAt = e.retryAt;
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        if (canPoll) _schedule();
      }
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (!_active || !canPoll || _pollCount >= 6) return;
    const delays = [2, 4, 8, 16, 30, 60];
    final backoff = Duration(seconds: delays[_pollCount++]);
    final retry = retryAt?.difference(DateTime.now()) ?? Duration.zero;
    _poll = Timer(
      retry > backoff ? retry : backoff,
      () => unawaited(refresh()),
    );
  }

  Future<void> cancel({bool completedVideoWarningAccepted = false}) async {
    final id = intent?.id;
    if (!_active ||
        !accessible ||
        id == null ||
        busy ||
        waiting ||
        intent?.status == RewardStatus.credited ||
        (completedVideo && !completedVideoWarningAccepted)) {
      return;
    }
    final epoch = _epoch;
    busy = true;
    failure = null;
    _poll?.cancel();
    _notify();
    try {
      await repository.cancelReward(id, _scope);
      if (!_alive(epoch) || intent?.id != id) return;
      cancelled = true;
      intent = null;
      _platform = null;
      completedVideo = false;
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        failure = e;
        retryAt = e.retryAt;
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        if (failure?.code == 'reward_not_found') unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    suspend(notify: false);
    repository.session.removeListener(_sessionChanged);
    intent = null;
    _platform = null;
    super.dispose();
  }
}
