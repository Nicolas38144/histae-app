import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../continuation/presentation/continuation_page.dart';
import '../../privacy/presentation/report_page.dart';
import '../application/matches_controller.dart';
import 'conversation_header.dart';
import 'match_photo_avatar.dart';
import 'matches_strings.dart';
import 'message_bubble.dart';
import 'partner_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller, required this.matchId});
  final MatchesController controller;
  final String matchId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  MatchesController get c => widget.controller;
  late final _text = TextEditingController(text: c.draftFor(widget.matchId));
  late final _key = c.session.resourceKey;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _incoming = <String, GlobalKey>{};
  Timer? _readTimer;
  String? _head;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (!mounted || !_foreground) return;
    _readTimer = Timer(const Duration(milliseconds: 450), _readVisible);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _readTimer?.cancel();
    if (state == AppLifecycleState.resumed) _scheduleRead();
  }

  void _readVisible({bool explicitRetry = false}) {
    if (!mounted ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true ||
        !c.canRead ||
        c.selectedId != widget.matchId) {
      return;
    }
    final view = _viewport.currentContext?.findRenderObject();
    if (view is! RenderBox || !view.attached || !view.hasSize) return;
    final bounds = view.localToGlobal(Offset.zero) & view.size;
    for (final message in c.messages) {
      if (message.senderId == c.ownerId || message.readAt != null) {
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
    if (!await confirmAction(
          context,
          block
              ? AppStrings.of(context).messages.encounterPageBlockThisPerson
              : AppStrings.of(context).messages.chatPageEndThisMatch,
          block
              ? AppStrings.of(context).messages.chatPageTheMatchWillEndAndYou
              : AppStrings.of(context)
                    .messages
                    .chatPageTheConversationWillNoLongerBe,
          action: block
              ? AppStrings.of(context).messages.discoveryPageBlock
              : AppStrings.of(context).messages.chatPageEnd,
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
    if (mounted) await c.continuation.activate();
  }

  Future<void> _profile() async {
    if (!c.accessible ||
        c.selected?.id != widget.matchId ||
        c.selected?.historyAllowed != true) {
      return;
    }
    _readTimer?.cancel();
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerPage(controller: c, id: widget.matchId),
      ),
    );
    if (mounted) _scheduleRead();
  }

  Future<void> _report() async {
    final match = c.selected;
    if (match == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPage(
          session: c.session,
          target: match.partner.id,
          matchId: widget.matchId,
          onBlock: () => c.endCurrent(block: true),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      return const HistaeScaffold(body: SizedBox.shrink());
    }
    final messages = c.messages;
    final match = c.selectedId == widget.matchId ? c.selected : null;
    final unavailable = match == null || !match.historyAllowed;
    return HistaeScaffold(
      appBar: AppBar(
        title: Semantics(
          button: !unavailable,
          child: Tooltip(
            message: AppStrings.of(context).messages.chatPageViewTheirProfile,
            child: InkWell(
              onTap: unavailable ? null : _profile,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (match != null) ...[
                      MatchPhotoAvatar(
                        key: ValueKey('${c.ownerId}:${match.id}'),
                        url: match.partner.photo,
                        readAt: c.readAt,
                        allowed:
                            c.active &&
                            c.verified &&
                            match.historyAllowed &&
                            match.photosRevealed &&
                            !c.photosBlocked(match.id),
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        match?.partner.firstname ??
                            AppStrings.of(context)
                                .messages
                                .continuationPageYourMatch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context)
                .messages
                .chatPageRefreshConversation,
            onPressed: c.listLoading || c.retrySeconds > 0 ? null : c.activate,
            icon: const Icon(Icons.refresh),
          ),
          if (match != null)
            PopupMenuButton<String>(
              tooltip: AppStrings.of(context).messages.chatPageMatchOptions,
              onSelected: (value) {
                if (value == 'decisions') unawaited(_decisions());
                if (value == 'profile') unawaited(_profile());
                if (value == 'end') unawaited(_end(block: false));
                if (value == 'block') unawaited(_end(block: true));
                if (value == 'report') unawaited(_report());
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'decisions',
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .chatPagePhotosAndContinuation,
                  ),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: Text(
                    AppStrings.of(context).messages.chatPageViewTheirProfile,
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .encounterPageReportThisPerson,
                  ),
                ),
                PopupMenuItem(
                  value: 'end',
                  enabled: !c.sending && !c.ending,
                  child: Text(AppStrings.of(context).messages.chatPageEndMatch),
                ),
                PopupMenuItem(
                  value: 'block',
                  enabled: !c.sending && !c.ending,
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .encounterPageBlockThisPerson447,
                  ),
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
                        ? AppStrings.of(context)
                              .messages
                              .continuationPageYourMatch
                        : AppStrings.of(context)
                              .messages
                              .chatPageThisMatchHasEnded,
                    body: c.failure != null || c.listLoading
                        ? AppStrings.of(context)
                              .messages
                              .chatPageRefreshTheMatchToOpenThe
                        : AppStrings.of(context)
                              .messages
                              .chatPageTheConversationIsNoLongerAvailable,
                  ),
                  if (c.failure case final error?)
                    Text(MatchesStrings(AppStrings.of(context)).failure(error)),
                  HistaeButton.outlined(
                    onPressed: c.listLoading || c.retrySeconds > 0
                        ? null
                        : c.activate,
                    child: Text(
                      AppStrings.of(context).messages.chatPageRefreshMyMatches,
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, layout) => Column(
                  children: [
                    ConversationHeader(
                      match: match,
                      compact:
                          layout.maxHeight < 480 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.4,
                      loading: c.listLoading || c.historyLoading,
                      onDecisions: _decisions,
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
                            itemCount:
                                messages.length +
                                (c.messageCursor == null ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return HistaeButton.text(
                                  onPressed: c.historyLoading || c.listLoading
                                      ? null
                                      : c.older,
                                  child: Text(
                                    AppStrings.of(context)
                                        .messages
                                        .chatPageOlderMessages,
                                  ),
                                );
                              }
                              final m = messages[index];
                              final own = m.senderId == c.ownerId;
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
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: layout.maxWidth * .86,
                                        ),
                                        child: MessageBubble(
                                          message: m,
                                          own: own,
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
                                  child: Text(
                                    MatchesStrings(AppStrings.of(context))
                                        .failure(error),
                                  ),
                                ),
                              ),
                            if (c.readFailure != null)
                              HistaeButton.text(
                                onPressed: c.reading
                                    ? null
                                    : () => _readVisible(explicitRetry: true),
                                child: Text(
                                  AppStrings.of(context)
                                      .messages
                                      .chatPageResumeReadConfirmation,
                                ),
                              ),
                            if (c.validation != null)
                              Text(
                                AppStrings.of(context)
                                    .clientMessage(c.validation!),
                              ),
                            if (c.retrySeconds > 0)
                              Text(
                                AppStrings.of(context).messages
                                    .appStringsTryAgainInS(c.retrySeconds),
                              ),
                            if (c.pendingEnd == widget.matchId ||
                                c.pendingBlock == widget.matchId) ...[
                              Text(
                                AppStrings.of(context)
                                    .messages
                                    .chatPageClosingStillNeedsConfirmationNoNew,
                              ),
                              HistaeButton.outlined(
                                onPressed: c.ending || c.retrySeconds > 0
                                    ? null
                                    : () => c.endCurrent(
                                        block: c.pendingBlock == widget.matchId,
                                      ),
                                child: Text(
                                  AppStrings.of(context)
                                      .messages
                                      .chatPageResumeTheSameRequest,
                                ),
                              ),
                            ] else if (c.pendingMessage != null) ...[
                              Text(
                                AppStrings.of(context)
                                    .messages
                                    .chatPageThisMessageIsAwaitingConfirmationResuming,
                              ),
                              HistaeButton(
                                onPressed: c.canSend ? c.resumeSend : null,
                                child: Text(
                                  c.sending
                                      ? AppStrings.of(context)
                                            .messages
                                            .chatPageSending
                                      : AppStrings.of(context)
                                            .messages
                                            .chatPageResumeTheSameMessage,
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
                                  labelText: AppStrings.of(context)
                                      .messages
                                      .chatPageYourMessage,
                                  helperText: AppStrings.of(context).messages
                                      .chatPage2000Characters(
                                        _text.text.runes.length,
                                      ),
                                ),
                                onChanged: (text) {
                                  c.setDraft(widget.matchId, text);
                                  setState(() {});
                                },
                              ),
                            if (match.sendAllowed && c.pendingMessage == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: HistaeButton.icon(
                                  onPressed: c.canSend
                                      ? () => c.send(_text.text)
                                      : null,
                                  icon: const Icon(Icons.send_outlined),
                                  label: Text(
                                    AppStrings.of(context)
                                        .messages
                                        .chatPageSend,
                                  ),
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
