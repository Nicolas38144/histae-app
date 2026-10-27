import '../data/match_models.dart';

/// Drafts can be restored from the device vault; send intentions stay in memory.
/// A pending message freezes its content and key until a definitive response.
class MessageOutbox {
  MessageOutbox({this.onChanged});
  final void Function(String id, String? text)? onChanged;
  final _drafts = <String, String>{};
  final _pending = <String, MessageIntent>{};

  Iterable<String> get matchIds => {..._drafts.keys, ..._pending.keys};

  bool hasPending(String id) => _pending.containsKey(id);

  MessageIntent? pendingFor(String? id) => _pending[id];

  String draftFor(String id) => _pending[id]?.content ?? _drafts[id] ?? '';

  void setDraft(String id, String text) {
    if (!hasPending(id)) {
      _drafts[id] = text;
      onChanged?.call(id, text);
    }
  }

  void restore(Map<String, String> values) {
    _drafts.removeWhere((id, _) => !hasPending(id) && !values.containsKey(id));
    for (final entry in values.entries) {
      if (!hasPending(entry.key)) {
        _drafts[entry.key] = entry.value;
      }
    }
  }

  void prepare(String id, String text) {
    if (hasPending(id)) return;
    final intent = MessageIntent(id, text);
    _pending[id] = intent;
    _drafts[id] = intent.content;
    // Once submitted, a message must never return as a new sendable draft.
    onChanged?.call(id, null);
  }

  void forgetPending(String id) {
    _pending.remove(id);
    onChanged?.call(id, _drafts[id]);
  }

  void forget(String id) {
    _pending.remove(id);
    _drafts.remove(id);
    onChanged?.call(id, null);
  }

  void clear() {
    _drafts.clear();
    _pending.clear();
  }
}
