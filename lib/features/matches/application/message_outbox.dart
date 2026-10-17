import '../data/match_models.dart';

/// In-memory drafts and immutable send intentions. A pending message freezes
/// its exact content and key until a definitive response resolves it.
class MessageOutbox {
  final _drafts = <String, String>{};
  final _pending = <String, MessageIntent>{};
  Iterable<String> get matchIds => {..._drafts.keys, ..._pending.keys};
  bool hasPending(String id) => _pending.containsKey(id);
  MessageIntent? pendingFor(String? id) => _pending[id];
  String draftFor(String id) => _pending[id]?.content ?? _drafts[id] ?? '';
  void setDraft(String id, String text) {
    if (!hasPending(id)) _drafts[id] = text;
  }

  void prepare(String id, String text) {
    if (hasPending(id)) return;
    final intent = MessageIntent(id, text);
    _pending[id] = intent;
    _drafts[id] = intent.content;
  }

  void forgetPending(String id) => _pending.remove(id);
  void forget(String id) {
    _pending.remove(id);
    _drafts.remove(id);
  }

  void clear() {
    _drafts.clear();
    _pending.clear();
  }
}
