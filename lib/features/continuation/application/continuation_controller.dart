import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../catalog/data/subscription_plan.dart';
import '../../matches/data/match_models.dart';
import '../data/continuation_models.dart';
import '../data/continuation_repository.dart';
import 'match_access.dart';
import 'reward_tracker.dart';

class ContinuationController extends ChangeNotifier {
  ContinuationController(
    this.access, {
    ContinuationRepository? repository,
    DateTime Function()? now,
  }) : repository = repository ?? ContinuationRepository(access.session),
       _now = now ?? DateTime.now {
    _key = access.session.resourceKey;
    _privacy = access.privacyEpoch;
    _revision = access.readRevision;
    access.addListener(_changed);
    access.session.addListener(_changed);
  }
  final MatchAccess access;
  final ContinuationRepository repository;
  RewardTracker? _rewards;

  RewardTracker get rewards =>
      _rewards ??= RewardTracker(repository, onCredited: loadQuota);
  final DateTime Function() _now;
  late String _key;
  late int _privacy, _revision;
  bool _disposed = false, _active = false;
  int _epoch = 0;
  RequestCancellation _scope = RequestCancellation();
  Future<void>? _load;
  late final RetryTicker _retryTimer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  DateTime? _retryAt;
  ContinuationQuota? quota;
  DateTime? quotaReadAt;
  List<SubscriptionPlan> plans = const [];
  bool loading = false, busy = false;
  ApiFailure? failure, catalogFailure;
  String? notice;
  ContinuationOffer? _offer;
  final _pendingContinue = <String, int>{}, _pendingReveal = <String>{};
  final _continued = <String>{}, _revealed = <String>{};

  bool get accessible =>
      !_disposed &&
      access.session.hasSession &&
      access.session.phase == SessionPhase.ready;

  bool get active => _active && accessible;

  UserMatch? get match => access.selected;

  int? get pendingCost => _pendingContinue[access.selectedId];

  bool get pendingReveal => _pendingReveal.contains(access.selectedId);

  bool get myContinued =>
      match?.myContinued == true || _continued.contains(access.selectedId);

  bool get myRevealed =>
      match?.myRevealed == true || _revealed.contains(access.selectedId);

  bool get canDecide =>
      active &&
      access.active &&
      access.verified &&
      match?.historyAllowed == true &&
      !access.ending &&
      !busy &&
      !loading &&
      retrySeconds == 0 &&
      (match!.status == MatchStatus.confirmed ||
          match!.expiresAt.isAfter(access.serverNow));

  bool get canContinue =>
      canDecide &&
      match?.status == MatchStatus.awaitingContinuation &&
      !myContinued;

  bool get canReveal => canDecide && !myRevealed;

  bool get advertisingEnabled {
    final current = quota;
    if (current == null || current.premium) return false;
    return plans.any(
      (p) =>
          p.code == current.plan &&
          p.rewardedAdvertisingEnabled &&
          !p.adsRemoved,
    );
  }

  int get retrySeconds => retrySecondsUntil(_retryAt, now: _now());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!accessible ||
        _key != access.session.resourceKey ||
        _privacy != access.privacyEpoch) {
      _key = access.session.resourceKey;
      _privacy = access.privacyEpoch;
      suspend(notify: false);
      quota = null;
      quotaReadAt = null;
      plans = const [];
      failure = null;
      catalogFailure = null;
      notice = null;
      _pendingContinue.clear();
      _pendingReveal.clear();
      _continued.clear();
      _revealed.clear();
      _retryAt = null;
      _retryTimer.cancel();
    }
    for (final id in {
      ..._pendingContinue.keys,
      ..._pendingReveal,
      ..._continued,
      ..._revealed,
    }) {
      if (access.isRemoved(id)) {
        _pendingContinue.remove(id);
        _pendingReveal.remove(id);
        _continued.remove(id);
        _revealed.remove(id);
      }
    }
    if (_revision != access.readRevision) {
      _revision = access.readRevision;
      _offer = null;
      final m = match;
      if (m != null) {
        _continued.remove(m.id);
        _revealed.remove(m.id);
        if (m.myContinued || m.status == MatchStatus.confirmed) {
          _pendingContinue.remove(m.id);
        }
        if (m.myRevealed) _pendingReveal.remove(m.id);
      }
    }
    if (!access.active && busy) {
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      busy = false;
    }
    _notify();
  }

  Future<void> activate() => _activate(loadIfMissing: true);

  Future<void> refreshQuota() async {
    await _activate(loadIfMissing: false);
    await loadQuota();
  }

  Future<void> _activate({required bool loadIfMissing}) async {
    if (!accessible) return;
    if (!_active) {
      _active = true;
      _scope = RequestCancellation();
    }
    final epoch = _epoch;
    await _load;
    if (loadIfMissing && _alive(epoch) && quota == null && failure == null) {
      await loadQuota();
    }
  }

  void forgetMatch(String id) {
    _pendingContinue.remove(id);
    _pendingReveal.remove(id);
    _continued.remove(id);
    _revealed.remove(id);
    if (_offer?.matchId == id) _offer = null;
    if (access.selectedId == id && busy) {
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      busy = false;
      loading = false;
    }
  }

  void suspend({bool notify = true}) {
    _rewards?.suspend(notify: false);
    _active = false;
    _epoch++;
    _scope.cancel();
    _offer = null;
    loading = false;
    busy = false;
    if (notify) _notify();
  }

  bool _alive(int epoch) => active && epoch == _epoch;

  void _error(ApiFailure e) {
    failure = e;
    _offer = null;
    if (e.retryAt != null &&
        (_retryAt == null || e.retryAt!.isAfter(_retryAt!))) {
      _retryAt = e.retryAt;
    }
    if (retrySeconds > 0) {
      _retryTimer.cancel();
      _retryTimer.restart();
    }
    if (e.kind == ApiFailureKind.consentRequired) {
      unawaited(access.session.synchronize());
    }
  }

  Future<void> loadQuota() {
    if (_load case final pending?) return pending;
    if (!active || retrySeconds > 0) return Future.value();
    final task = _loadQuota();
    _load = task;
    return task.whenComplete(() {
      if (identical(_load, task)) _load = null;
    });
  }

  Future<void> _loadQuota() async {
    final epoch = _epoch;
    loading = true;
    failure = null;
    catalogFailure = null;
    _offer = null;
    _notify();
    try {
      final q = await repository.quota(_scope);
      if (!_alive(epoch)) return;
      quota = q;
      quotaReadAt = _now().toUtc();
      try {
        final result = await repository.plans(_scope);
        if (_alive(epoch)) plans = result;
      } on ApiFailure catch (e) {
        if (_alive(epoch)) {
          catalogFailure = e;
          plans = const [];
          if (e.retryAt != null) _error(e);
        }
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        quotaReadAt = null;
        _error(e);
      }
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<ContinuationOffer?> prepareContinuation() async {
    if (!active || busy || retrySeconds > 0 || pendingCost != null) return null;
    final id = access.selectedId, epoch = _epoch;
    await access.refresh();
    if (!_alive(epoch) || access.selectedId != id) return null;
    await loadQuota();
    if (!_alive(epoch) ||
        !canContinue ||
        quotaReadAt == null ||
        quota == null ||
        !quota!.canStart ||
        access.selectedId != id) {
      return null;
    }
    return _offer = ContinuationOffer(
      id!,
      quota!.creditCost,
      quota!.plan,
      access.readRevision,
      _now().toUtc(),
      _key,
    );
  }

  DateTime _week(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).subtract(Duration(days: utc.weekday - 1));
  }

  Future<void> accept(ContinuationOffer offer) async {
    if (!canContinue || pendingCost != null) return;
    final now = _now().toUtc();
    if (!identical(_offer, offer) ||
        offer.resourceKey != _key ||
        offer.matchId != access.selectedId ||
        offer.readRevision != access.readRevision ||
        now.difference(offer.createdAt) > const Duration(minutes: 1) ||
        _week(now) != _week(offer.createdAt)) {
      notice = 'cost_changed';
      _offer = null;
      _notify();
      await loadQuota();
      return;
    }
    _offer = null;
    _pendingContinue[offer.matchId] = offer.cost;
    await resumeContinuation();
  }

  Future<void> resumeContinuation() async {
    final m = match, cost = pendingCost;
    if (!canContinue || m == null || cost == null) return;
    await _decision(
      m.id,
      () => repository.continueMatch(m.id, cost, _scope),
      continuation: true,
    );
  }

  Future<void> reveal() async {
    final m = match;
    if (!canReveal || m == null) return;
    _pendingReveal.add(m.id);
    await _decision(
      m.id,
      () => repository.reveal(m.id, _scope),
      continuation: false,
    );
  }

  Future<void> _decision(
    String id,
    Future<bool> Function() send, {
    required bool continuation,
  }) async {
    final epoch = _epoch;
    ApiFailure? outcome;
    busy = true;
    failure = null;
    notice = null;
    _notify();
    try {
      await send(); // Acknowledgement never substitutes for the fresh match.
      if (!_alive(epoch)) return;
      if (continuation) {
        _pendingContinue.remove(id);
        _continued.add(id);
        notice = 'continued';
      } else {
        _pendingReveal.remove(id);
        _revealed.add(id);
        notice = 'revealed';
      }
    } on ApiFailure catch (e) {
      if (!_alive(epoch)) return;
      outcome = e;
      _error(e);
      if ([
        'continuation_plan_changed',
        'continuation_quota_reached',
        'continuation_not_available_yet',
        'invalid_continuation_request',
      ].contains(e.code)) {
        _pendingContinue.remove(id);
        _continued.remove(id);
        quotaReadAt = null;
      }
      if ([
        'match_not_found',
        'match_expired',
        'invalid_match_state',
        'match_blocked',
      ].contains(e.code)) {
        access.removeUnavailable(id);
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        await access.refresh();
        if (_alive(epoch)) await loadQuota();
        if (_alive(epoch) && outcome != null) {
          failure = outcome;
          _notify();
        }
      }
    }
  }

  @override
  void dispose() {
    _rewards?.dispose();
    _disposed = true;
    suspend(notify: false);
    _retryTimer.cancel();
    access.removeListener(_changed);
    access.session.removeListener(_changed);
    _pendingContinue.clear();
    _pendingReveal.clear();
    _continued.clear();
    _revealed.clear();
    quota = null;
    plans = const [];
    super.dispose();
  }
}
