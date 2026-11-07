import '../../../core/network/api_failure.dart';
import '../data/match_models.dart';

/// Drafts and immutable send intentions are restored from the account's vault.
/// A pending message freezes its content and key until a definitive response.
class MessageOutbox {
  MessageOutbox({this.onChanged, this.onPendingChanged});
  final void Function(String id, List<MessageIntent> values)? onPendingChanged;
  final void Function(String id, String? text)? onChanged;
  final _drafts = <String, String>{};
  final _pending = <String, List<MessageIntent>>{};
  final _failures = <String, ApiFailure>{};

  Iterable<String> get matchIds => {..._drafts.keys, ..._pending.keys};

  MessageIntent? pendingFor(String? id) => _pending[id]?.firstOrNull;

  List<MessageIntent> pendingMessages(String? id) =>
      List.unmodifiable(_pending[id] ?? const <MessageIntent>[]);

  ApiFailure? failureFor(String? id) => _failures[id];

  String draftFor(String id) => _drafts[id] ?? '';

  void setDraft(String id, String text) {
    _drafts[id] = text;
    onChanged?.call(id, text);
  }

  void restore(Map<String, String> values) {
    _drafts.removeWhere((id, _) => !values.containsKey(id));
    for (final entry in values.entries) {
      _drafts[entry.key] = entry.value;
    }
  }

  void prepare(String id, String text) {
    final intent = MessageIntent(id, text);
    (_pending[id] ??= []).add(intent);
    _drafts.remove(id);
    // Once submitted, a message must never return as a new sendable draft.
    onChanged?.call(id, null);
    onPendingChanged?.call(id, pendingMessages(id));
  }

  void restorePending(List<MessageIntent> values) {
    for (final intent in values) {
      final items = _pending[intent.matchId] ??= [];
      if (!items.any((item) => item.key == intent.key)) items.add(intent);
    }
  }

  void acknowledge(String id, MessageIntent intent) {
    if (!identical(pendingFor(id), intent)) return;
    _pending[id]!.removeAt(0);
    if (_pending[id]!.isEmpty) _pending.remove(id);
    _failures.remove(id);
    onPendingChanged?.call(id, pendingMessages(id));
  }

  void fail(String id, MessageIntent intent, ApiFailure error) {
    if (identical(pendingFor(id), intent)) _failures[id] = error;
  }

  void clearFailure(String id) => _failures.remove(id);

  void interrupt(String? id) {
    if (id == null || pendingFor(id) == null) return;
    _failures.putIfAbsent(id, () => const ApiFailure(ApiFailureKind.cancelled));
  }

  void forget(String id) {
    _pending.remove(id);
    _failures.remove(id);
    _drafts.remove(id);
    onChanged?.call(id, null);
    onPendingChanged?.call(id, const []);
  }

  void clear() {
    _drafts.clear();
    _pending.clear();
    _failures.clear();
  }
}
