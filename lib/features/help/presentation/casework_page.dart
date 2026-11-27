import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/generated/app_messages.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/request_cancellation.dart';
import '../../../core/text/text_limit_input_formatter.dart';
import '../../../core/text/text_limits.dart';
import '../../../core/text/whitespace.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/text_limit_highlight.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_strings.dart';
import '../data/casework_entry.dart';
import 'casework_strings.dart';
import 'support_request_widgets.dart';

enum CaseworkView { reports, support, receipt, thread }

class CaseworkPage extends StatefulWidget {
  const CaseworkPage({
    super.key,
    required this.view,
    required this.session,
    this.requestId,
    this.showExport = false,
    this.openExport,
  });

  final CaseworkView view;
  final AuthenticatedSession session;
  final String? requestId;
  final bool showExport;
  final ValueChanged<String>? openExport;

  @override
  State<CaseworkPage> createState() => _CaseworkPageState();
}

class _CaseworkPageState extends State<CaseworkPage>
    with WidgetsBindingObserver {
  final _scope = RequestCancellation();
  final _message = TextEditingController();
  final _rows = <CaseworkEntry>[];
  late final String _account;
  String? _before;
  String? _initial;
  String? _threadStatus;
  String? _exportId;
  String? _issuedCode;
  DateTime? _codeExpiry;
  ApiFailure? _error;
  String _category = 'login';
  bool _busy = false;
  bool _sessionLost = false;

  bool get _canReply =>
      _threadStatus == 'pending' || _threadStatus == 'in_progress';

  bool get _singleSupportCase =>
      widget.view == CaseworkView.support && widget.requestId != null;

  bool get _hasList => {
    CaseworkView.reports,
    CaseworkView.support,
    CaseworkView.thread,
  }.contains(widget.view);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _account = widget.session.resourceKey;
    widget.session.addListener(_onSessionChanged);
    if (_hasList) unawaited(_run(() => _load()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasList) {
      unawaited(_run(_load));
    }
  }

  void _onSessionChanged() {
    if (widget.session.resourceKey == _account && widget.session.hasSession) {
      return;
    }
    _scope.cancel();
    setState(() {
      _sessionLost = true;
      _rows.clear();
      _initial = null;
      _issuedCode = null;
      _exportId = null;
      _message.clear();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChanged);
    _scope.cancel();
    _message.dispose();
    super.dispose();
  }

  String get _threadPath =>
      '/api/users/me/data-subject-requests/${Uri.encodeComponent(widget.requestId!)}/messages';

  Future<Object?> _authenticated(
    String method,
    String path, {
    Object? body,
    int expected = 200,
    Map<String, String>? query,
  }) => widget.session.request(
    method,
    path,
    body: body,
    query: query,
    expectedStatus: expected,
    replayAfterRefresh: method == 'GET',
    cancellation: _scope,
  );

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _scope.isCancelled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (!_scope.isCancelled) {
        _error = error;
        if (error.code == 'case_not_found') {
          _rows.clear();
          _before = null;
          _initial = null;
          _threadStatus = null;
          _exportId = null;
        }
      }
    } finally {
      if (mounted && !_scope.isCancelled) setState(() => _busy = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_singleSupportCase) {
      final id = widget.requestId!;
      serverId({'id': id}, 'id');
      final row = CaseworkEntry.fromJson(
        await _authenticated('GET', '/api/users/me/support-cases/$id'),
        isThread: false,
      );
      if (row.id != id) invalidResponse();
      if (!_scope.isCancelled) {
        _rows
          ..clear()
          ..add(row);
      }
      return;
    }
    final (path, key) = switch (widget.view) {
      CaseworkView.reports => ('/api/users/me/reports', 'reports'),
      CaseworkView.support => ('/api/users/me/support-cases', 'cases'),
      CaseworkView.thread => (_threadPath, 'messages'),
      _ => throw StateError('This screen has no list'),
    };
    final page = jsonObject(
      await _authenticated(
        'GET',
        path,
        query: more && _before != null ? {'before': _before!} : null,
      ),
    );
    final isThread = widget.view == CaseworkView.thread;
    final rows = jsonField<List<dynamic>>(
      page,
      key,
    ).map((row) => CaseworkEntry.fromJson(row, isThread: isThread)).toList();
    final before = page['next_cursor'] == null
        ? null
        : serverId(page, 'next_cursor');
    final initial = isThread ? optionalText(page, 'details') : null;
    final status = isThread ? jsonString(page, 'status') : null;
    if (_scope.isCancelled) return;
    if (!more) _rows.clear();
    final ids = _rows.map((row) => row.id).toSet();
    _rows.addAll(rows.where((row) => ids.add(row.id)));
    _before = before;
    if (isThread) {
      _initial = initial;
      _threadStatus = status;
      if (widget.showExport && !more) {
        _exportId = null;
        final grant = await _authenticated(
          'GET',
          '/api/users/me/data-subject-requests/${Uri.encodeComponent(widget.requestId!)}/assisted-export',
        );
        if (!_scope.isCancelled) {
          final document = grant == null ? null : jsonObject(grant);
          _exportId =
              document != null &&
                  wireTime(document['expires_at'])
                      .isAfter(DateTime.now().toUtc())
              ? serverId(document, 'id')
              : null;
        }
      }
    }
  }

  bool get _validMessage {
    final text = trimOuterWhitespace(_message.text);
    return text.isNotEmpty &&
        text.runes.length <= longTextCharacterLimit &&
        !RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]').hasMatch(text);
  }

  Future<void> _send() async {
    if (!_validMessage) return;
    final message = trimOuterWhitespace(_message.text);
    switch (widget.view) {
      case CaseworkView.thread:
        if (!_canReply) return;
        await _authenticated(
          'POST',
          _threadPath,
          body: {'message': message},
          expected: 204,
        );
      case CaseworkView.support:
        final created = jsonObject(
          await _authenticated(
            'POST',
            '/api/users/me/support-cases',
            body: {'category': _category, 'message': message},
            expected: 201,
          ),
        );
        serverId(created, 'id');
      default:
        return;
    }
    if (_scope.isCancelled) return;
    _message.clear();
    if (_hasList) await _load();
  }

  Future<void> _issueReceipt() async {
    final answer = jsonObject(
      await _authenticated('POST', '/api/users/me/erasure-receipt'),
    );
    if (_scope.isCancelled) return;
    _issuedCode = jsonString(answer, 'code');
    _codeExpiry = wireTime(answer['expires_at']);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final support = widget.view == CaseworkView.support;
    final title = switch (widget.view) {
      CaseworkView.reports => text.caseworkReports,
      CaseworkView.support => text.caseworkSupport,
      CaseworkView.receipt => text.caseworkReceipt,
      CaseworkView.thread => text.caseworkThread,
    };
    return HistaeScaffold(
      appBar: AppBar(title: Text(title)),
      body: _sessionLost
          ? const SizedBox.shrink()
          : ListView(
              padding: HistaeTokens.pagePadding,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error case final error?)
                  Text(
                    error.code == 'case_not_found'
                        ? text.caseworkUnavailable
                        : strings.authFailure(error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (widget.view == CaseworkView.receipt) ...[
                  Text(text.caseworkReceiptHelp),
                  const SizedBox(height: 12),
                  if (_issuedCode == null)
                    HistaeButton(
                      onPressed: _busy ? null : () => _run(_issueReceipt),
                      child: Text(text.caseworkGenerate),
                    ),
                ],
                if (support && !_singleSupportCase) ...[
                  SupportRequestForm(
                    category: _category,
                    onCategoryChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _category = value ?? _category),
                    composer: _compose(text),
                  ),
                  const SizedBox(height: HistaeTokens.contentSpacing),
                ],
                if (_issuedCode case final code?)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text.caseworkSaveCode),
                          SelectableText(code),
                          if (_codeExpiry case final expiresAt?)
                            Text(privacyDate(strings, expiresAt)),
                          HistaeButton.text(
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: code)),
                            child: Text(text.caseworkCopy),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_hasList) ...[
                  if (support && !_singleSupportCase)
                    _supportHistoryHeading(text)
                  else if (!_singleSupportCase || _error != null) ...[
                    const SizedBox(height: HistaeTokens.textSpacing),
                    HistaeButton.text(
                      onPressed: _busy ? null : () => _run(() => _load()),
                      child: Text(text.caseworkRefresh),
                    ),
                  ],
                  if (widget.view == CaseworkView.thread && _initial != null)
                    _entry(text.caseworkYou, _initial!),
                  for (final row
                      in widget.view == CaseworkView.thread
                          ? _rows.reversed
                          : _rows)
                    if (widget.view == CaseworkView.thread)
                      _entry(
                        row.fromTeam ? text.caseworkTeam : text.caseworkYou,
                        row.body,
                      )
                    else if (support)
                      SupportRequestCard(entry: row)
                    else
                      _reportCard(row, text),
                  if (!_busy &&
                      _rows.isEmpty &&
                      _initial == null &&
                      _error == null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: HistaeTokens.labelSpacing,
                      ),
                      child: Text(
                        support ? text.supportNoRequests : text.caseworkEmpty,
                      ),
                    ),
                  if (_before != null)
                    HistaeButton.outlined(
                      onPressed: _busy
                          ? null
                          : () => _run(() => _load(more: true)),
                      child: Text(text.caseworkMore),
                    ),
                ],
                if (widget.view == CaseworkView.thread && _canReply)
                  _compose(text),
                if (_exportId case final id?)
                  HistaeButton.outlined(
                    onPressed: () => widget.openExport?.call(id),
                    child: Text(text.caseworkAssistedExport),
                  ),
              ],
            ),
    );
  }

  Widget _compose(AppMessages text) {
    final support = widget.view == CaseworkView.support;
    final decoration = InputDecoration(
      labelText: text.caseworkMessage,
      helperText: support ? null : text.caseworkLimit,
      alignLabelWithHint: true,
    );
    Widget field(InputDecoration decoration) => TextField(
      controller: _message,
      enableIMEPersonalizedLearning: false,
      inputFormatters: const [
        TextLimitInputFormatter(TextLengthLimit(longTextCharacterLimit)),
      ],
      minLines: 3,
      maxLines: 8,
      enabled: !_busy,
      decoration: decoration,
      onChanged: (_) => setState(() {}),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (support)
          TextLimitHighlight(
            reached: _message.text.runes.length >= longTextCharacterLimit,
            limitHint: text.caseworkMessageLimitReached,
            decoration: decoration,
            builder: field,
          )
        else
          field(decoration),
        const SizedBox(
          height: HistaeTokens.contentSpacing - HistaeTokens.actionSpacing / 2,
        ),
        HistaeButton(
          onPressed: _busy || !_validMessage ? null : () => _run(_send),
          child: Text(text.caseworkSend),
        ),
      ],
    );
  }

  Widget _supportHistoryHeading(AppMessages text) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text.supportRequestHistory,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(width: HistaeTokens.labelSpacing),
        IconButton(
          onPressed: _busy ? null : () => _run(() => _load()),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: text.caseworkRefresh,
        ),
      ],
    );
  }

  Widget _reportCard(CaseworkEntry entry, AppMessages text) {
    final topic = caseworkValueLabel(text, entry.topic);
    final status = caseworkValueLabel(text, entry.status);
    return _entry(
      '$topic · $status',
      entry.body,
      response: entry.response,
      team: text.caseworkTeam,
    );
  }

  Widget _entry(String title, String body, {String? response, String? team}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (body.isNotEmpty) SelectableText(body),
              if (response != null) ...[
                const SizedBox(height: 12),
                Text(team!, style: Theme.of(context).textTheme.titleSmall),
                SelectableText(response),
              ],
            ],
          ),
        ),
      );
}
