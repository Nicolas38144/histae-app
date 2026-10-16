import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../profile/presentation/profile_editors.dart';
import '../application/matches_controller.dart';
import '../../continuation/presentation/continuation_page.dart';
import '../../continuation/presentation/partner_photo_page.dart';
import 'matches_strings.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller, required this.matchId});
  final MatchesController controller;
  final String matchId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  MatchesController get c => widget.controller;
  late final _text = TextEditingController(text: c.draftFor(widget.matchId));
  late final _key = c.session.resourceKey;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _incoming = <String, GlobalKey>{};
  Timer? _readTimer;
  String? _head;
  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _scroll.addListener(_scheduleRead);
    _scheduleRead();
  }

  void _changed() {
    if (!mounted) return;
    final draft = c.draftFor(widget.matchId);
    if (_text.text != draft) {
      _text.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    final head = c.messages.isEmpty ? null : c.messages.first.id;
    final preserve =
        _head != null &&
        _head != head &&
        _scroll.hasClients &&
        _scroll.offset > 24;
    final oldMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final oldOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    _head = head;
    setState(() {});
    if (preserve) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(
            (oldOffset + _scroll.position.maxScrollExtent - oldMax).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    }
    _scheduleRead();
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    if (!mounted) return;
    _readTimer = Timer(const Duration(milliseconds: 450), _readVisible);
  }

  void _readVisible({bool explicitRetry = false}) {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !c.canRead ||
        c.selectedId != widget.matchId) {
      return;
    }
    final view = _viewport.currentContext?.findRenderObject();
    if (view is! RenderBox || !view.attached || !view.hasSize) return;
    final bounds = view.localToGlobal(Offset.zero) & view.size;
    for (final message in c.messages) {
      if (message.senderId == c.repository.owner || message.readAt != null) {
        continue;
      }
      final box = _incoming[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.bottom > bounds.top &&
          rect.bottom <= bounds.bottom &&
          rect.left < bounds.right) {
        unawaited(c.markRead(message.id, explicitRetry: explicitRetry));
        return;
      }
    }
  }

  Future<void> _end({required bool block}) async {
    if (!await confirmProfileAction(
          context,
          block ? 'Bloquer cette personne ?' : 'Terminer cette rencontre ?',
          block
              ? 'La rencontre sera terminée et vous ne pourrez plus vous découvrir ni échanger.'
              : 'La conversation ne sera plus accessible. Cette action ne bloque pas cette personne. Un crédit déjà débité ne sera pas remboursé.',
          action: block ? 'Bloquer' : 'Terminer',
        ) ||
        !mounted) {
      return;
    }
    await c.endCurrent(block: block);
    if (mounted && c.selected == null) Navigator.of(context).pop();
  }

  Future<void> _decisions() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContinuationPage(
          controller: c.continuation,
          matchId: widget.matchId,
        ),
      ),
    );
    if (mounted && c.active) unawaited(c.refresh());
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    c.removeListener(_changed);
    _scroll.removeListener(_scheduleRead);
    _scroll.dispose();
    _text.dispose();
    c.closeChat(widget.matchId, notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!c.accessible || c.session.resourceKey != _key) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final match = c.selectedId == widget.matchId ? c.selected : null;
    final unavailable = match == null || !match.historyAllowed;
    return Scaffold(
      appBar: AppBar(
        title: Text(match?.partner.firstname ?? 'Votre rencontre'),
        actions: [
          IconButton(
            tooltip: 'Actualiser la conversation',
            onPressed: c.listLoading || c.retrySeconds > 0 ? null : c.activate,
            icon: const Icon(Icons.refresh),
          ),
          if (match != null)
            PopupMenuButton<String>(
              tooltip: 'Options de la rencontre',
              onSelected: (value) {
                if (value == 'decisions') unawaited(_decisions());
                if (value == 'profile') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _PartnerPage(controller: c, id: widget.matchId),
                    ),
                  );
                }
                if (value == 'end') unawaited(_end(block: false));
                if (value == 'block') unawaited(_end(block: true));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'decisions',
                  child: Text('Photos et continuation'),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('Voir son profil'),
                ),
                PopupMenuItem(
                  value: 'end',
                  enabled: !c.sending && !c.ending,
                  child: const Text('Terminer la rencontre'),
                ),
                PopupMenuItem(
                  value: 'block',
                  enabled: !c.sending && !c.ending,
                  child: const Text('Bloquer cette personne'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: unavailable
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  EditorialCard(
                    title: c.failure != null || c.listLoading
                        ? 'Votre rencontre'
                        : 'Cette rencontre\nest terminée.',
                    body: c.failure != null || c.listLoading
                        ? 'La rencontre doit être relue pour ouvrir la conversation.'
                        : 'La conversation n’est plus disponible.',
                  ),
                  if (c.failure case final error?)
                    Text(MatchesStrings.failure(error)),
                  OutlinedButton(
                    onPressed: c.listLoading || c.retrySeconds > 0
                        ? null
                        : c.activate,
                    child: const Text('Relire mes rencontres'),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, layout) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: layout.maxHeight * .25,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              MatchesStrings.status(match.status),
                              style: layout.maxHeight < 480
                                  ? Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          height: 1.15,
                                          fontWeight: FontWeight.w600,
                                        )
                                  : Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              MatchesStrings.stateBody(match),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _decisions,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text(
                                  match.status.name == 'awaitingContinuation'
                                      ? 'Choisir la suite'
                                      : 'Photos et continuation',
                                ),
                              ),
                            ),
                            if (!c.realtimeConnected)
                              const Text(
                                'Connexion en reprise · actualisation manuelle disponible.',
                                style: TextStyle(fontSize: 12),
                              ),
                            if (c.listLoading || c.historyLoading)
                              const LinearProgressIndicator(
                                semanticsLabel:
                                    'Synchronisation de la conversation',
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        key: _viewport,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (event) {
                            _scheduleRead();
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: c.messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == c.messages.length) {
                                return c.messageCursor != null
                                    ? TextButton(
                                        onPressed:
                                            c.historyLoading || c.listLoading
                                            ? null
                                            : c.older,
                                        child: const Text(
                                          'Messages plus anciens',
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          c.messages.isEmpty
                                              ? 'Quelques mots pour commencer ?'
                                              : 'Le début de votre conversation',
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                              }
                              final m = c.messages[index];
                              final own = m.senderId == c.repository.owner;
                              return Padding(
                                key: own
                                    ? ValueKey(m.id)
                                    : _incoming.putIfAbsent(
                                        m.id,
                                        GlobalKey.new,
                                      ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: own
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: layout.maxWidth * .86,
                                        ),
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: own
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SelectableText(m.content),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${MatchesStrings.date(m.createdAt)}${own ? (m.readAt == null ? ' · Envoyé' : ' · Lu') : ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: layout.maxHeight * .5,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (c.chatFailure case final error?)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(MatchesStrings.failure(error)),
                                ),
                              ),
                            if (c.readFailure != null)
                              TextButton(
                                onPressed: c.reading
                                    ? null
                                    : () => _readVisible(explicitRetry: true),
                                child: const Text(
                                  'Reprendre la confirmation de lecture',
                                ),
                              ),
                            if (c.validation != null) Text(c.validation!),
                            if (c.retrySeconds > 0)
                              Text(
                                'Nouvel essai possible dans ${c.retrySeconds} s',
                              ),
                            if (c.pendingEnd == widget.matchId ||
                                c.pendingBlock == widget.matchId) ...[
                              const Text(
                                'La clôture reste à confirmer. Aucun nouveau message ne sera envoyé.',
                              ),
                              OutlinedButton(
                                onPressed: c.ending || c.retrySeconds > 0
                                    ? null
                                    : () => c.endCurrent(
                                        block: c.pendingBlock == widget.matchId,
                                      ),
                                child: const Text('Reprendre la même demande'),
                              ),
                            ] else if (c.pendingMessage != null) ...[
                              const Text(
                                'Cet envoi attend sa confirmation. Reprendre conserve exactement les mêmes mots et la même demande.',
                              ),
                              FilledButton(
                                onPressed: c.canSend ? c.resumeSend : null,
                                child: Text(
                                  c.sending
                                      ? 'Envoi en cours…'
                                      : 'Reprendre le même envoi',
                                ),
                              ),
                            ],
                            if (match.sendAllowed)
                              TextField(
                                controller: _text,
                                minLines: 1,
                                maxLines: 4,
                                readOnly:
                                    !c.canSend || c.pendingMessage != null,
                                decoration: InputDecoration(
                                  labelText: 'Votre message',
                                  helperText:
                                      '${_text.text.runes.length} / 2 000 caractères',
                                ),
                                onChanged: (text) {
                                  c.setDraft(widget.matchId, text);
                                  setState(() {});
                                },
                              ),
                            if (match.sendAllowed && c.pendingMessage == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: FilledButton.icon(
                                  onPressed: c.canSend
                                      ? () => c.send(_text.text)
                                      : null,
                                  icon: const Icon(Icons.send_outlined),
                                  label: const Text('Envoyer'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PartnerPage extends StatelessWidget {
  const _PartnerPage({required this.controller, required this.id});
  final MatchesController controller;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final match =
          controller.selectedId == id &&
              controller.accessible &&
              controller.selected?.historyAllowed == true
          ? controller.selected
          : null;
      return Scaffold(
        appBar: AppBar(title: Text(match?.partner.firstname ?? 'Profil')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (match == null)
                const Text('Ce profil n’est plus disponible.')
              else ...[
                EditorialCard(
                  title: '${match.partner.firstname}, ${match.partner.age}',
                  body:
                      match.partner.bio ??
                      'Découvrez cette personne au fil de vos échanges.',
                ),
                const SizedBox(height: 24),
                if (match.photosRevealed && match.partner.photo != null)
                  OutlinedButton.icon(
                    onPressed: !controller.verified
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PartnerPhotoPage(
                                access: controller,
                                matchId: id,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Voir sa photo'),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: match.partner.traits
                      .map((t) => Chip(label: Text(t)))
                      .toList(),
                ),
                for (final answer in match.partner.answers) ...[
                  const EditorialDivider(),
                  Text(
                    answer.question,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(answer.answer),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}
