import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../consents/domain/consent_state.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';
import '../data/discovery_repository.dart';

class EncounterReceipt {
  const EncounterReceipt(this.match, this.profile);
  final ReceivedMatch match;
  final FeedProfile profile;
}

class DiscoveryController extends ChangeNotifier {
  DiscoveryController(
    this.repository,
    this.location, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _resourceKey = session.resourceKey;
    session.addListener(_sessionChanged);
  }
  final DiscoveryRepository repository;
  final LocationSource location;
  final DateTime Function() _now;
  AuthenticatedSession get session => repository.session;
  late String _resourceKey;
  RequestCancellation _scope = RequestCancellation();
  int _epoch = 0;
  bool _active = false, _disposed = false;
  bool loading = false, locating = false, sending = false;
  DiscoveryStatus? status;
  ApiFailure? failure;
  LocationIssue? locationIssue;
  String? notice;
  bool approximate = false, uncertain = false;
  final _queue = <FeedProfile>[];
  final _seen = <String>{}, _removed = <String>{};
  String? _cursor;
  bool exhausted = false;
  PendingChoice? pending;
  EncounterReceipt? encounter;
  void forgetEncounter(String matchId) {
    if (encounter?.match.id != matchId) return;
    encounter = null;
    if (!_disposed) notifyListeners();
  }

  Timer? _expiryTimer;
  late final RetryTicker _retryTimer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  DateTime? _retryAt, _checkedExpiry;
  bool get accessible =>
      !_disposed && session.hasSession && session.phase == SessionPhase.ready;
  bool get active => _active && accessible;
  bool get ready => status?.ready == true;
  bool get busy => loading || locating || sending;
  bool get canChoose =>
      active &&
      ready &&
      !busy &&
      pending == null &&
      failure == null &&
      retrySeconds == 0 &&
      current != null;
  bool get canResume =>
      active &&
      !busy &&
      pending != null &&
      (ready || pending!.action == PendingAction.block) &&
      retrySeconds == 0;
  bool get locationConsent =>
      session.consents?.consents.any(
        (c) => c.type == ConsentType.location && c.current,
      ) ??
      false;
  FeedProfile? get current =>
      pending?.profile ?? (_queue.isEmpty ? null : _queue.first);
  int get retrySeconds => retrySecondsUntil(_retryAt, now: _now());

  bool _alive(int epoch) => active && epoch == _epoch && !_scope.isCancelled;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_resourceKey == session.resourceKey && accessible) return;
    _resourceKey = session.resourceKey;
    deactivate();
    status = null;
    pending = null;
    encounter = null;
    failure = null;
    locationIssue = null;
    approximate = false;
    uncertain = false;
    notice = null;
    _queue.clear();
    _seen.clear();
    _removed.clear();
    _cursor = null;
    _retryAt = null;
    _checkedExpiry = null;
    _retryTimer.cancel();
    _notify();
  }

  Future<void> activate() async {
    if (!accessible || _active) return;
    _active = true;
    _scope = RequestCancellation();
    await refresh();
  }

  void deactivate({bool notify = true}) {
    _active = false;
    _epoch++;
    _scope.cancel();
    _expiryTimer?.cancel();
    if (sending && pending != null) uncertain = true;
    loading = false;
    locating = false;
    sending = false;
    _queue.clear();
    _seen.clear();
    _cursor = null;
    status = null;
    exhausted = false;
    // Keep only a pending immutable choice and receipt within this session.
    if (notify) _notify();
  }

  void _error(ApiFailure error) {
    failure = error;
    if (error.retryAt != null &&
        (_retryAt == null || error.retryAt!.isAfter(_retryAt!))) {
      _retryAt = error.retryAt;
    }
    if (retrySeconds > 0) {
      _retryTimer.cancel();
      _retryTimer.restart();
    }
    if (error.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  void _armExpiry() {
    _expiryTimer?.cancel();
    final expires = status?.presenceExpiresAt;
    if (expires == null || expires == _checkedExpiry) return;
    final wait = expires.difference(_now().toUtc());
    _expiryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (!active) return;
      _checkedExpiry = expires;
      // The local deadline invalidates the displayed batch and triggers a read;
      // it never manufactures a server readiness result or publishes GPS.
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      if (sending && pending != null) uncertain = true;
      status = null;
      _queue.clear();
      _seen.clear();
      _cursor = null;
      loading = false;
      locating = false;
      sending = false;
      _notify();
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (!active || busy || retrySeconds > 0) return;
    final epoch = _epoch;
    loading = true;
    failure = null;
    locationIssue = null;
    if (pending == null) {
      _queue.clear();
      _seen.clear();
      _cursor = null;
      exhausted = false;
    }
    _notify();
    try {
      final next = await repository.status(_scope);
      if (!_alive(epoch)) return;
      status = next;
      _armExpiry();
      if (!next.ready) {
        _queue.clear();
        _seen.clear();
        _cursor = null;
      } else if (pending == null) {
        await _readPages(epoch);
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e);
        if (e.kind == ApiFailureKind.discoveryNotReady) {
          status = null;
          _queue.clear();
          try {
            final diagnostic = await repository.status(_scope);
            if (_alive(epoch)) {
              status = diagnostic;
              _armExpiry();
            }
          } on ApiFailure catch (again) {
            if (_alive(epoch)) _error(again);
          }
        }
      }
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _readPages(int epoch) async {
    var restarted = false;
    for (var page = 0; page < 3; page++) {
      FeedPage result;
      try {
        result = await repository.feed(_cursor, _scope);
      } on ApiFailure catch (e) {
        if (!_alive(epoch)) return;
        if (e.code == 'invalid_cursor' && !restarted) {
          restarted = true;
          _cursor = null;
          _seen.clear();
          _queue.clear();
          result = await repository.feed(null, _scope);
        } else {
          rethrow;
        }
      }
      if (!_alive(epoch)) return;
      if (result.nextCursor != null && result.nextCursor == _cursor) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      for (final profile in result.profiles) {
        if (profile.id == session.identity?.userId) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        if (!_removed.contains(profile.id) && _seen.add(profile.id)) {
          _queue.add(profile);
        }
      }
      _cursor = result.nextCursor;
      exhausted = _cursor == null;
      if (_queue.isNotEmpty || exhausted) return;
    }
  }

  Future<void> loadMore() async {
    if (!active ||
        busy ||
        !ready ||
        pending != null ||
        exhausted ||
        retrySeconds > 0) {
      return;
    }
    final epoch = _epoch;
    loading = true;
    failure = null;
    _notify();
    try {
      await _readPages(epoch);
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e);
        if (e.kind == ApiFailureKind.discoveryNotReady) {
          status = null;
        }
      }
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
    if (_alive(epoch) && status == null) await refresh();
  }

  Future<void> publishLocation() async {
    if (!active || busy || retrySeconds > 0 || !locationConsent) return;
    final epoch = _epoch;
    locating = true;
    notice = null;
    locationIssue = null;
    failure = null;
    _notify();
    try {
      // Check consent again before transmission, after any native permission UI.
      final fix = await location.locate(_scope);
      if (!_alive(epoch) || !locationConsent) return;
      if (!fix.freshAt(_now())) {
        throw const LocationFailure(LocationIssue.stale);
      }
      await repository.presence(fix.latitude, fix.longitude, _scope);
      if (!_alive(epoch)) return;
      approximate = fix.approximate;
      notice = fix.approximate ? 'location_approximate' : 'location_updated';
    } on LocationFailure catch (e) {
      if (_alive(epoch)) locationIssue = e.issue;
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e);
        notice = 'presence_uncertain';
      }
    } finally {
      if (_alive(epoch)) {
        locating = false;
        _notify();
      }
    }
    // No replay of a position write. Re-read its server result instead.
    if (_alive(epoch) && locationIssue == null && retrySeconds == 0) {
      await refresh();
    }
  }

  Future<EncounterReceipt?> decide(SwipeDecision decision) async {
    if (!canChoose) return null;
    pending = PendingChoice(
      current!,
      decision == SwipeDecision.like ? PendingAction.like : PendingAction.pass,
    );
    return resumeChoice();
  }

  Future<EncounterReceipt?> blockProfile(FeedProfile profile) async {
    if (!active || busy || retrySeconds > 0) return null;
    // An explicit block supersedes an uncertain like/pass, never changes it to
    // its opposite. The server invalidates any match already created.
    pending = PendingChoice(profile, PendingAction.block);
    return resumeChoice();
  }

  Future<EncounterReceipt?> resumeChoice() async {
    if (!canResume) return null;
    final intent = pending!;
    final epoch = _epoch;
    sending = true;
    notice = null;
    failure = null;
    _notify();
    EncounterReceipt? received;
    var reread = false;
    try {
      if (intent.action == PendingAction.block) {
        await repository.block(intent, _scope);
      } else {
        final result = await repository.swipe(intent, _scope);
        if (result.match case final match?) {
          received = EncounterReceipt(match, intent.profile);
        }
      }
      if (!_alive(epoch)) return null;
      _removed.add(intent.profile.id);
      _queue.removeWhere((p) => p.id == intent.profile.id);
      pending = null;
      uncertain = false;
      if (intent.action == PendingAction.block) {
        if (encounter?.profile.id == intent.profile.id) encounter = null;
        notice = 'blocked';
      } else {
        notice = intent.action == PendingAction.like ? 'liked' : 'passed';
        if (received != null) encounter = received;
      }
    } on ApiFailure catch (e) {
      if (!_alive(epoch)) return null;
      if ([
        'discovery_candidate_not_found',
        'swipe_already_recorded',
        'match_blocked',
        'user_not_found',
      ].contains(e.code)) {
        _removed.add(intent.profile.id);
        _queue.removeWhere((p) => p.id == intent.profile.id);
        pending = null;
        uncertain = false;
        notice = 'candidate_unavailable';
      } else {
        _error(e);
        uncertain = [
          ApiFailureKind.network,
          ApiFailureKind.timeout,
          ApiFailureKind.server,
          ApiFailureKind.invalidResponse,
          ApiFailureKind.unavailable,
          ApiFailureKind.cancelled,
        ].contains(e.kind);
        if (e.kind == ApiFailureKind.discoveryNotReady) {
          status = null;
          _queue.clear();
          reread = true;
        }
      }
    } finally {
      if (_alive(epoch)) {
        sending = false;
        _notify();
      }
    }
    if (_alive(epoch)) {
      if (reread && retrySeconds == 0) {
        await refresh();
      } else if (pending == null && _queue.isEmpty && !exhausted) {
        unawaited(loadMore());
      }
    }
    return received;
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _epoch++;
    _scope.cancel();
    _expiryTimer?.cancel();
    _retryTimer.cancel();
    session.removeListener(_sessionChanged);
    _queue.clear();
    _seen.clear();
    _removed.clear();
    pending = null;
    encounter = null;
    status = null;
    super.dispose();
  }
}
