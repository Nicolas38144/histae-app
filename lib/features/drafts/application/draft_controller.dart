import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async/serial_executor.dart';
import '../../auth/domain/authenticated_session.dart';
import '../data/draft_snapshot.dart';
import '../data/draft_vault.dart';
import '../data/saved_answer_draft.dart';

/// Stores unsent text only, scoped to a verified account and API origin.
class DraftController extends ChangeNotifier {
  DraftController(this.session, this.vault) {
    session.addListener(_sessionChanged);
    _sessionChanged();
  }

  final AuthenticatedSession session;
  final DraftVault vault;
  final _queue = SerialExecutor();
  final _messages = <String, String>{};
  List<SavedAnswerDraft>? _answers;
  String? _owner;
  int _epoch = 0;
  bool _disposed = false, loaded = false, storageFailed = false;
  Timer? _debounce;
  Future<void> _ready = Future.value();

  Future<void> get ready => _ready;
  Map<String, String> get messages => Map.unmodifiable(_messages);
  List<SavedAnswerDraft>? get answers =>
      _answers == null ? null : List.unmodifiable(_answers!);

  bool _alive(int epoch) => !_disposed && _epoch == epoch;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_disposed) return;
    if (session.phase == SessionPhase.signedOut ||
        !session.hasSession && session.phase == SessionPhase.storageFailure) {
      _owner = null;
      _epoch++;
      _debounce?.cancel();
      _messages.clear();
      _answers = null;
      loaded = false;
      _ready = _queue.run(() async {
        try {
          await vault.write(null);
          storageFailed = false;
        } catch (_) {
          storageFailed = true;
        }
        _notify();
      });
      _notify();
      return;
    }
    if (session.phase != SessionPhase.ready || session.identity == null) return;
    final owner = '${session.apiOrigin}|${session.identity!.userId}';
    if (_owner == owner) return;
    _owner = owner;
    final epoch = ++_epoch;
    loaded = false;
    _messages.clear();
    _answers = null;
    _ready = _queue.run(() async {
      try {
        final raw = await vault.read();
        if (!_alive(epoch)) return;
        if (raw != null) {
          final value = DraftSnapshot.decode(raw);
          if (value.owner != owner) {
            await vault.write(null);
          } else {
            if (!_alive(epoch)) return;
            _messages.addAll(value.messages);
            _answers = value.answers;
          }
        }
        if (_alive(epoch)) storageFailed = false;
      } catch (_) {
        if (_alive(epoch)) storageFailed = true;
      } finally {
        if (_alive(epoch)) {
          loaded = true;
          _notify();
        }
      }
    });
  }

  void setMessage(String id, String? text) {
    if (!loaded || _owner == null) return;
    if (text == null || text.isEmpty) {
      _messages.remove(id);
    } else {
      _messages[id] = text;
    }
    _schedule();
  }

  void setAnswers(List<SavedAnswerDraft>? values) {
    if (!loaded || _owner == null) return;
    _answers = values == null ? null : List.of(values);
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(flush()),
    );
    _notify();
  }

  Future<bool> flush() {
    _debounce?.cancel();
    if (!loaded || _owner == null || _disposed) return Future.value(false);
    final epoch = _epoch;
    final value = _messages.isEmpty && _answers == null
        ? null
        : DraftSnapshot(
            owner: _owner!,
            messages: _messages,
            answers: _answers,
          ).encode();
    return _queue.run(() async {
      if (_epoch != epoch || _owner == null) return false;
      try {
        await vault.write(value);
        if (_epoch != epoch || _owner == null) return false;
        storageFailed = false;
        _notify();
        return true;
      } catch (_) {
        if (_alive(epoch)) {
          storageFailed = true;
          _notify();
        }
        return false;
      }
    });
  }

  @override
  void dispose() {
    // Ordinary app disposal preserves drafts; sign-out queues their removal.
    unawaited(flush());
    _disposed = true;
    _debounce?.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
