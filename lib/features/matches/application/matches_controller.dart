import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/client_message.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/read_snapshots.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../continuation/application/continuation_controller.dart';
import '../../continuation/application/match_access.dart';
import '../data/match_models.dart';
import '../data/matches_repository.dart';
import '../data/realtime_client.dart';
import 'message_outbox.dart';

class MatchesController extends ChangeNotifier implements MatchAccess {
  MatchesController(
    this.repository, {
    RealtimeClient? realtime,
    DateTime Function()? now,
    this.onRemoved,
  }) : realtime = realtime ?? RealtimeClient(repository.session),
       _now = now ?? DateTime.now {
    _key = session.resourceKey;
    _localeRevision = session.localizationRevision;
    session.addListener(_sessionChanged);
    this.realtime.onSignal = _signal;
    this.realtime.onState = (connected, _) {
      if (!active || !_realtimeEnabled) return;
      realtimeConnected = connected;
      _notify();
    };
  }
  final MatchesRepository repository;

  String get ownerId => repository.owner;
  ContinuationController? _continuation;

  ContinuationController get continuation =>
      _continuation ??= ContinuationController(this);
  @override
  int readRevision = 0, privacyEpoch = 0;
  @override
  DateTime? readAt;

  @override
  bool isRemoved(String id) =>
      _removed.contains(id) ||
      _items.any((m) => m.id == id && !m.historyAllowed);

  @override
  void removeUnavailable(String id) {
    _purge(id, remove: true);
    _notify();
    _schedule();
  }

  final RealtimeClient realtime;
  bool _realtimeEnabled = true;

  void setRealtimeEnabled(bool enabled) {
    if (_realtimeEnabled == enabled) return;
    _realtimeEnabled = enabled;
    if (!enabled) {
      realtime.stop();
      _debounce?.cancel();
      _dirty = false;
      realtimeConnected = false;
    } else if (active && retrySeconds == 0) {
      realtime.start();
      unawaited(_read(ReadPolicy.cached));
    }
  }

  final DateTime Function() _now;
  final void Function(String)? onRemoved;

  @override
  AuthenticatedSession get session => repository.session;
  late String _key;
  late int _localeRevision;
  bool _disposed = false, _active = false, _verified = false, _dirty = false;
  int _epoch = 0, _chatEpoch = 0, _listRevision = 0;
  @override
  int privateRevision = 0;
  RequestCancellation _scope = RequestCancellation(),
      _chatScope = RequestCancellation();
  Future<void>? _sync;
  Timer? _debounce, _deadline;
  late final RetryTicker _cooldown = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  Duration _clockOffset = Duration.zero;
  final _checkedDeadlines = <String>{},
      _removed = <String>{},
      _readAttempted = <String>{};
  final _outbox = MessageOutbox();
  final _closures = <String, bool>{};
  final _items = <UserMatch>[];
  final _messages = <ChatMessage>[];

  List<UserMatch> get items => List.unmodifiable(_items);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? listCursor, messageCursor;
  @override
  String? selectedId;

  String? get pendingEnd => _closures[selectedId] == false ? selectedId : null;

  String? get pendingBlock => _closures[selectedId] == true ? selectedId : null;
  int _historyPages = 1;
  bool listLoading = false,
      historyLoading = false,
      sending = false,
      reading = false;
  @override
  bool ending = false;
  bool realtimeConnected = false;
  ApiFailure? failure, chatFailure, readFailure;
  String? notice;
  ClientMessage? validation;
  DateTime? _retryAt;

  bool get accessible =>
      !_disposed && session.hasSession && session.phase == SessionPhase.ready;

  @override
  bool get active => _active && accessible;

  @override
  bool get verified => _verified;

  @override
  DateTime get serverNow => _now().toUtc().add(_clockOffset);

  @override
  UserMatch? get selected {
    for (final item in _items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  String draftFor(String id) => _outbox.draftFor(id);

  MessageIntent? get pendingMessage => _outbox.pendingFor(selectedId);

  bool get canSend =>
      active &&
      _verified &&
      selected?.sendAllowed == true &&
      (selected!.status == MatchStatus.confirmed ||
          selected!.expiresAt.isAfter(serverNow)) &&
      !sending &&
      !ending &&
      pendingEnd != selectedId &&
      pendingBlock != selectedId &&
      retrySeconds == 0;

  bool get canRead =>
      active && _verified && selected?.historyAllowed == true && !ending;

  int get retrySeconds => retrySecondsUntil(_retryAt, now: _now());

  bool _alive(int epoch) => active && epoch == _epoch;

  bool _chatAlive(int epoch, int chatEpoch, String id) =>
      _alive(epoch) && chatEpoch == _chatEpoch && selectedId == id;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDraft(String id, String text) {
    if (accessible && !_outbox.hasPending(id) && !_removed.contains(id)) {
      _outbox.setDraft(id, text);
    }
  }

  void _sessionChanged() {
    if (_key == session.resourceKey && accessible) {
      if (_localeRevision != session.localizationRevision) {
        _localeRevision = session.localizationRevision;
        _dirty = true;
        _verified = false;
        _notify();
        _schedule();
      }
      return;
    }
    _key = session.resourceKey;
    _localeRevision = session.localizationRevision;
    privacyEpoch++;
    suspend();
    _items.clear();
    _messages.clear();
    _outbox.clear();
    _removed.clear();
    _readAttempted.clear();
    selectedId = null;
    _closures.clear();
    _checkedDeadlines.clear();
    _clockOffset = Duration.zero;
    _dirty = false;
    listCursor = null;
    messageCursor = null;
    failure = null;
    chatFailure = null;
    readFailure = null;
    notice = null;
    privateRevision++;
    _retryAt = null;
    _cooldown.cancel();
    _notify();
  }

  Future<void> activate({bool refresh = false}) async {
    if (!accessible || _active) return;
    if (!_active) {
      _active = true;
      _scope = RequestCancellation();
      _chatScope = RequestCancellation();
    }
    final epoch = _epoch;
    await _sync;
    if (!_alive(epoch)) return;
    await _read(refresh ? ReadPolicy.refresh : ReadPolicy.cached);
    if (active && _realtimeEnabled && retrySeconds == 0) realtime.start();
  }

  void suspend({bool notify = true}) {
    _active = false;
    _epoch++;
    _chatEpoch++;
    _scope.cancel();
    _chatScope.cancel();
    realtime.stop();
    _deadline?.cancel();
    _debounce?.cancel();
    _verified = false;
    realtimeConnected = false;
    listLoading = false;
    historyLoading = false;
    sending = false;
    reading = false;
    ending = false;
    if (notify) _notify();
  }

  void _error(ApiFailure error, {bool chat = false}) {
    if (chat) {
      chatFailure = error;
    } else {
      failure = error;
    }
    if (error.retryAt != null &&
        (_retryAt == null || error.retryAt!.isAfter(_retryAt!))) {
      _retryAt = error.retryAt;
    }
    if (retrySeconds > 0) {
      _cooldown.cancel();
      _cooldown.restart();
    }
    if (error.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  void _purge(String id, {bool remove = false}) {
    repository.invalidate(matchId: id);
    _continuation?.forgetMatch(id);
    _outbox.forget(id);
    _readAttempted.removeWhere((key) => key.startsWith('$id:'));
    _closures.remove(id);
    if (selectedId == id) {
      _chatEpoch++;
      _chatScope.cancel();
      _chatScope = RequestCancellation();
      _messages.clear();
      messageCursor = null;
      _verified = false;
      sending = false;
      reading = false;
      historyLoading = false;
    }
    if (remove) {
      _removed.add(id);
      _items.removeWhere((m) => m.id == id);
    }
    privateRevision++;
    onRemoved?.call(id);
  }

  void _signal(MobileSignal signal) {
    if (!active || !_realtimeEnabled) return;
    if (signal.serverTime case final time?) {
      _clockOffset = time.difference(_now().toUtc());
      _armDeadline();
    }
    if (signal.type == 'heartbeat') return;
    repository.invalidate(matchId: signal.matchId);
    if (signal.ended && signal.matchId != null) {
      _purge(signal.matchId!, remove: true);
      notice = 'ended';
      _notify();
    } else if (signal.type == 'matches.invalidated') {
      privacyEpoch++;
      _epoch++;
      _chatEpoch++;
      _scope.cancel();
      _chatScope.cancel();
      _scope = RequestCancellation();
      _chatScope = RequestCancellation();
      listLoading = false;
      historyLoading = false;
      sending = false;
      reading = false;
      ending = false;
      for (final id in {
        ..._outbox.matchIds,
        ..._closures.keys,
        ..._items.map((m) => m.id),
      }) {
        _purge(id);
      }
      _items.clear();
      _messages.clear();
      _verified = false;
      _notify();
    } else if (signal.type != 'message.read') {
      _verified = false;
      _notify();
    }
    _schedule();
  }

  void _schedule() {
    if (!active || !_realtimeEnabled) return;
    if (_sync != null || listLoading || historyLoading) {
      _dirty = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(refresh()),
    );
  }

  void _armDeadline() {
    _deadline?.cancel();
    DateTime? next;
    for (final match in _items) {
      if (match.status != MatchStatus.active &&
          match.status != MatchStatus.awaitingContinuation) {
        continue;
      }
      if (_checkedDeadlines.contains(
        '${match.id}:${match.status.name}:${match.expiresAt.toIso8601String()}',
      )) {
        continue;
      }
      if (next == null || match.expiresAt.isBefore(next)) {
        next = match.expiresAt;
      }
    }
    if (next == null) return;
    final delay = next.difference(serverNow);
    _deadline = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!active) return;
      for (final match in _items) {
        if (!match.expiresAt.isAfter(serverNow)) {
          _checkedDeadlines.add(
            '${match.id}:${match.status.name}:${match.expiresAt.toIso8601String()}',
          );
        }
      }
      _verified = false;
      _notify();
    });
  }

  @override
  Future<void> refresh() => _read(ReadPolicy.refresh);

  Future<void> _read(ReadPolicy policy) {
    if (_sync case final pending?) return pending;
    if (!active || retrySeconds > 0) return Future.value();
    if (listLoading || historyLoading) {
      _dirty = true;
      return Future.value();
    }
    final task = _refresh(policy);
    _sync = task;
    return task.whenComplete(() {
      if (identical(_sync, task)) _sync = null;
      if (_dirty && active) {
        _dirty = false;
        _schedule();
      }
    });
  }

  Future<void> _refresh(ReadPolicy policy) async {
    final epoch = _epoch, chatEpoch = _chatEpoch;
    final languageRevision = session.localizationRevision;
    final target = selectedId;
    final scope = _scope;
    listLoading = true;
    failure = null;
    _verified = false;
    _listRevision++;
    _notify();
    try {
      final items = <UserMatch>[];
      final seen = <String>{}, cursors = <String>{};
      String? cursor;
      do {
        final page = await repository.matches(
          scope,
          cursor: cursor,
          policy: policy,
        );
        if (!_alive(epoch)) return;
        if (languageRevision != session.localizationRevision) {
          _dirty = true;
          return;
        }
        for (final item in page.items) {
          if (!_removed.contains(item.id) &&
              seen.add(item.id) &&
              item.status != MatchStatus.ended) {
            items.add(item);
          }
        }
        cursor = page.cursor;
        if (cursor != null && !cursors.add(cursor)) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
      } while (cursor != null && target != null && !seen.contains(target));
      if (!_alive(epoch)) return;
      _items
        ..clear()
        ..addAll(items);
      listCursor = cursor;
      readRevision++;
      readAt = repository.matchesReadAt;
      if (cursor == null) {
        for (final id in {..._outbox.matchIds, ..._closures.keys}) {
          if (!seen.contains(id)) _purge(id);
        }
      }
      _armDeadline();
      if (target != null && _chatAlive(epoch, chatEpoch, target)) {
        final match = selected;
        if (match == null || !match.historyAllowed) {
          _purge(target);
          notice = 'ended';
        } else {
          await _refreshHistory(match, epoch, chatEpoch, policy);
        }
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _error(e);
    } finally {
      if (_alive(epoch)) {
        listLoading = false;
        _notify();
      }
    }
  }

  Future<void> _refreshHistory(
    UserMatch match,
    int epoch,
    int chatEpoch,
    ReadPolicy policy,
  ) async {
    final result = <ChatMessage>[];
    final seen = <String>{}, cursors = <String>{};
    String? cursor;
    final scope = _chatScope;
    try {
      for (var pageNumber = 0; pageNumber < _historyPages; pageNumber++) {
        final page = await repository.messages(
          match,
          scope,
          cursor: cursor,
          policy: policy,
        );
        if (!_chatAlive(epoch, chatEpoch, match.id)) return;
        for (final message in page.items) {
          if (seen.add(message.id)) result.add(message);
        }
        cursor = page.cursor;
        if (cursor == null) break;
        if (!cursors.add(cursor)) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
      }
      if (!_chatAlive(epoch, chatEpoch, match.id)) return;
      _messages
        ..clear()
        ..addAll(result);
      messageCursor = cursor;
      _verified = true;
      chatFailure = null;
    } on ApiFailure catch (e) {
      if (!_chatAlive(epoch, chatEpoch, match.id)) return;
      _error(e, chat: true);
      if (_denied(e)) {
        _purge(match.id, remove: true);
        notice = 'ended';
      }
      if (e.code == 'invalid_cursor') {
        _historyPages = 1;
        _dirty = true;
      }
    }
  }

  bool _denied(ApiFailure e) => [
    'match_not_found',
    'match_expired',
    'messaging_not_available',
    'invalid_match_state',
    'match_blocked',
  ].contains(e.code);

  Future<void> loadMore() async {
    if (!active ||
        listLoading ||
        historyLoading ||
        listCursor == null ||
        retrySeconds > 0) {
      return;
    }
    final epoch = _epoch, revision = _listRevision;
    final languageRevision = session.localizationRevision;
    final cursor = listCursor;
    listLoading = true;
    failure = null;
    _notify();
    try {
      final page = await repository.matches(_scope, cursor: cursor);
      if (!_alive(epoch) || revision != _listRevision) return;
      if (page.cursor != null && page.cursor == cursor) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      if (languageRevision != session.localizationRevision) {
        _dirty = true;
        return;
      }
      final ids = _items.map((m) => m.id).toSet();
      for (final item in page.items) {
        if (!_removed.contains(item.id) &&
            item.status != MatchStatus.ended &&
            ids.add(item.id)) {
          _items.add(item);
        }
      }
      listCursor = page.cursor;
      _armDeadline();
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e);
        if (e.code == 'invalid_cursor') _dirty = true;
      }
    } finally {
      if (_alive(epoch)) {
        listLoading = false;
        _notify();
        if (_dirty) {
          _dirty = false;
          _schedule();
        }
      }
    }
  }

  Future<void> openChat(String id) async {
    _chatEpoch++;
    _chatScope.cancel();
    _chatScope = RequestCancellation();
    selectedId = id;
    _messages.clear();
    _historyPages = 1;
    messageCursor = null;
    _verified = false;
    sending = false;
    reading = false;
    historyLoading = false;
    chatFailure = null;
    readFailure = null;
    notice = null;
    validation = null;
    _notify();
    await _sync;
    if (active && selectedId == id) await _read(ReadPolicy.cached);
  }

  void closeChat(String id, {bool notify = true}) {
    if (selectedId != id) return;
    _chatEpoch++;
    _chatScope.cancel();
    _chatScope = RequestCancellation();
    selectedId = null;
    _messages.clear();
    messageCursor = null;
    _verified = false;
    chatFailure = null;
    readFailure = null;
    sending = false;
    reading = false;
    historyLoading = false;
    if (notify) _notify();
  }

  Future<void> older() async {
    final match = selected;
    if (!canRead ||
        match == null ||
        historyLoading ||
        listLoading ||
        messageCursor == null ||
        retrySeconds > 0) {
      return;
    }
    final epoch = _epoch, chatEpoch = _chatEpoch;
    final cursor = messageCursor;
    historyLoading = true;
    _notify();
    try {
      final page = await repository.messages(match, _chatScope, cursor: cursor);
      if (!_chatAlive(epoch, chatEpoch, match.id)) return;
      if (page.cursor != null && page.cursor == cursor) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final ids = _messages.map((m) => m.id).toSet();
      for (final m in page.items) {
        if (ids.add(m.id)) _messages.add(m);
      }
      messageCursor = page.cursor;
      _historyPages++;
    } on ApiFailure catch (e) {
      if (_chatAlive(epoch, chatEpoch, match.id)) {
        _error(e, chat: true);
        if (_denied(e)) {
          _purge(match.id, remove: true);
          notice = 'ended';
        } else if (e.code == 'invalid_cursor') {
          _historyPages = 1;
          _dirty = true;
        }
      }
    } finally {
      if (_chatAlive(epoch, chatEpoch, match.id)) {
        historyLoading = false;
        _notify();
        if (_dirty) {
          _dirty = false;
          _schedule();
        }
      }
    }
  }

  Future<void> send(String raw) async {
    final match = selected;
    if (match == null || !canSend || _outbox.hasPending(match.id)) return;
    validation = validateMessage(raw);
    if (validation != null) {
      _notify();
      return;
    }
    _outbox.prepare(match.id, raw);
    await resumeSend();
  }

  Future<void> resumeSend() async {
    final match = selected, intent = pendingMessage;
    if (!canSend || match == null || intent == null) return;
    final epoch = _epoch, chatEpoch = _chatEpoch;
    sending = true;
    chatFailure = null;
    validation = null;
    _notify();
    try {
      final message = await repository.send(match, intent, _chatScope);
      if (!_chatAlive(epoch, chatEpoch, match.id)) return;
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.insert(0, message);
      }
      _outbox.forget(match.id);
      _schedule();
    } on ApiFailure catch (e) {
      if (_chatAlive(epoch, chatEpoch, match.id)) {
        _error(e, chat: true);
        if (e.code == 'invalid_message_request' ||
            e.code == 'invalid_message_payload') {
          _outbox.forgetPending(match.id);
        }
        if (e.code == 'match_expired' ||
            e.code == 'match_not_found' ||
            e.code == 'match_blocked') {
          _purge(match.id);
          notice = 'ended';
        }
        if (_denied(e)) {
          _verified = false;
          _schedule();
        }
      }
    } finally {
      if (_chatAlive(epoch, chatEpoch, match.id)) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> markRead(String messageId, {bool explicitRetry = false}) async {
    final id = selectedId;
    if (id == null || !canRead || reading || retrySeconds > 0) return;
    final incoming = _messages.where(
      (m) =>
          m.id == messageId &&
          m.senderId != repository.owner &&
          m.readAt == null,
    );
    if (incoming.isEmpty) return;
    final key = '$id:$messageId';
    if (explicitRetry) _readAttempted.remove(key);
    if (!_readAttempted.add(key)) return;
    final epoch = _epoch, chatEpoch = _chatEpoch;
    reading = true;
    readFailure = null;
    try {
      await repository.readThrough(id, messageId, _chatScope);
      if (_chatAlive(epoch, chatEpoch, id)) _schedule();
    } on ApiFailure catch (e) {
      if (_chatAlive(epoch, chatEpoch, id)) {
        readFailure = e;
        _error(e, chat: true);
        if (_denied(e)) {
          _purge(id, remove: true);
          notice = 'ended';
          _schedule();
        }
      }
    } finally {
      if (_chatAlive(epoch, chatEpoch, id)) {
        reading = false;
        _notify();
      }
    }
  }

  Future<void> endCurrent({bool block = false}) async {
    final match = selected;
    if (!active || match == null || ending || sending || retrySeconds > 0) {
      return;
    }
    final epoch = _epoch;
    if (block || !_closures.containsKey(match.id)) _closures[match.id] = block;
    ending = true;
    _verified = false;
    chatFailure = null;
    _notify();
    try {
      if (_closures[match.id] == true) {
        await repository.block(match.partner.id, _scope);
      } else {
        await repository.end(match.id, _scope);
      }
      if (!_alive(epoch)) return;
      _purge(match.id, remove: true);
      notice = 'ended';
      _schedule();
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e, chat: true);
        if (e.code == 'match_not_found') {
          _purge(match.id, remove: true);
          notice = 'ended';
        } else {
          _schedule();
        }
      }
    } finally {
      if (_alive(epoch)) {
        ending = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _continuation?.dispose();
    _disposed = true;
    suspend();
    realtime.dispose();
    _cooldown.cancel();
    session.removeListener(_sessionChanged);
    _items.clear();
    _messages.clear();
    _outbox.clear();
    _closures.clear();
    _readAttempted.clear();
    super.dispose();
  }
}
