import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_strings.dart';
import 'casework_strings.dart';

enum CaseworkView { reports, support, guest, receipt, thread }

class CaseworkPage extends StatefulWidget {
  const CaseworkPage({
    super.key,
    required this.view,
    this.session,
    this.publicApi,
    this.requestId,
    this.canReply = false,
    this.showExport = false,
    this.openExport,
  });

  final CaseworkView view;
  final AuthenticatedSession? session;
  final ApiClient? publicApi;
  final String? requestId;
  final bool canReply;
  final bool showExport;
  final ValueChanged<String>? openExport;

  @override
  State<CaseworkPage> createState() => _CaseworkPageState();
}

class _CaseworkPageState extends State<CaseworkPage> {
  final _scope = RequestCancellation();
  final _message = TextEditingController();
  final _followUpCode = TextEditingController();
  final _rows = <Map<String, dynamic>>[];
  late final String? _account;
  String? _before;
  String? _initial;
  String? _threadStatus;
  String? _exportId;
  String? _issuedCode;
  DateTime? _codeExpiry;
  String? _erasureStatus;
  Map<String, dynamic>? _foundCase;
  ApiFailure? _error;
  String _category = 'login';
  bool _busy = false;
  bool _lookupErasure = false;
  bool _sessionLost = false;

  bool get _canReply => switch (_threadStatus) {
    'pending' || 'in_progress' => true,
    null => widget.canReply,
    _ => false,
  };

  bool get _hasList => {
    CaseworkView.reports,
    CaseworkView.support,
    CaseworkView.thread,
  }.contains(widget.view);

  @override
  void initState() {
    super.initState();
    _account = widget.session?.resourceKey;
    widget.session?.addListener(_onSessionChanged);
    if (_hasList) unawaited(_run(() => _load()));
  }

  void _onSessionChanged() {
    if (widget.session?.resourceKey == _account &&
        widget.session?.hasSession == true) {
      return;
    }
    _scope.cancel();
    setState(() {
      _sessionLost = true;
      _rows.clear();
      _initial = null;
      _issuedCode = null;
      _message.clear();
    });
  }

  @override
  void dispose() {
    widget.session?.removeListener(_onSessionChanged);
    _scope.cancel();
    _message.dispose();
    _followUpCode.dispose();
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
  }) => widget.session!.request(
    method,
    path,
    body: body,
    query: query,
    expectedStatus: expected,
    replayAfterRefresh: method == 'GET',
    cancellation: _scope,
  );

  Future<Object?> _publicPost(String path, Object body, {int expected = 200}) =>
      widget.publicApi!.requestJson(
        'POST',
        path,
        body: body,
        expectedStatus: expected,
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
      if (!_scope.isCancelled) _error = error;
    } finally {
      if (mounted && !_scope.isCancelled) setState(() => _busy = false);
    }
  }

  Future<void> _load({bool more = false}) async {
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
    final rows = jsonField<List<dynamic>>(page, key).map(jsonObject).toList();
    for (final row in rows) {
      serverId(row, 'id');
    }
    if (_scope.isCancelled) return;
    if (!more) _rows.clear();
    final ids = _rows.map((row) => row['id']).toSet();
    _rows.addAll(rows.where((row) => ids.add(row['id'])));
    _before = pageCursor(page);
    if (widget.view == CaseworkView.thread) {
      _initial = optionalText(page, 'details');
      _threadStatus = jsonString(page, 'status');
      if (widget.showExport && !more) {
        final grant = await _authenticated(
          'GET',
          '/api/users/me/data-subject-requests/${Uri.encodeComponent(widget.requestId!)}/assisted-export',
        );
        if (!_scope.isCancelled) {
          _exportId = grant == null ? null : serverId(jsonObject(grant), 'id');
        }
      }
    }
  }

  bool get _validMessage {
    final text = _message.text.trim();
    return text.isNotEmpty &&
        text.runes.length <= 2000 &&
        !RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]').hasMatch(text);
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    switch (widget.view) {
      case CaseworkView.thread:
        await _authenticated(
          'POST',
          _threadPath,
          body: {'message': message},
          expected: 204,
        );
      case CaseworkView.support:
        await _authenticated(
          'POST',
          '/api/users/me/support-cases',
          body: {'category': _category, 'message': message},
          expected: 201,
        );
      case CaseworkView.guest:
        final answer = jsonObject(
          await _publicPost('/api/public/support-cases', {
            'category': _category,
            'message': message,
          }, expected: 201),
        );
        if (_scope.isCancelled) return;
        _issuedCode = jsonString(answer, 'code');
        _followUpCode.text = _issuedCode!;
        _lookupErasure = false;
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

  Future<void> _lookup() async {
    _erasureStatus = null;
    _foundCase = null;
    final path = _lookupErasure
        ? '/api/public/erasure-status'
        : '/api/public/support-cases/status';
    final reply = jsonObject(
      await _publicPost(path, {'code': _followUpCode.text.trim()}),
    );
    if (_scope.isCancelled) return;
    if (_lookupErasure) {
      _erasureStatus = jsonString(reply, 'status');
    } else {
      _foundCase = reply;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final s = caseworkStrings(strings.localeName);
    final title = switch (widget.view) {
      CaseworkView.reports => s('reports'),
      CaseworkView.support || CaseworkView.guest => s('support'),
      CaseworkView.receipt => s('receipt'),
      CaseworkView.thread => s('thread'),
    };
    return HistaeScaffold(
      appBar: AppBar(title: Text(title)),
      body: _sessionLost
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error case final error?)
                  Text(
                    error.code == 'case_not_found'
                        ? s('unavailable')
                        : strings.authFailure(error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (widget.view == CaseworkView.receipt) ...[
                  Text(s('receiptHelp')),
                  const SizedBox(height: 12),
                  if (_issuedCode == null)
                    HistaeButton(
                      onPressed: _busy ? null : () => _run(_issueReceipt),
                      child: Text(s('generate')),
                    ),
                ],
                if (widget.view == CaseworkView.guest ||
                    widget.view == CaseworkView.support) ...[
                  Text(
                    s(
                      widget.view == CaseworkView.guest
                          ? 'guestHelp'
                          : 'supportHelp',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _supportForm(s),
                ],
                if (_issuedCode case final code?)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s('saveCode')),
                          SelectableText(code),
                          if (_codeExpiry case final expiresAt?)
                            Text(privacyDate(strings, expiresAt)),
                          HistaeButton.text(
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: code)),
                            child: Text(s('copy')),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.view == CaseworkView.guest) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<bool>(
                    key: ValueKey(_lookupErasure),
                    initialValue: _lookupErasure,
                    decoration: InputDecoration(labelText: s('track')),
                    items: [
                      DropdownMenuItem(value: false, child: Text(s('support'))),
                      DropdownMenuItem(value: true, child: Text(s('receipt'))),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _lookupErasure = value ?? false;
                            _erasureStatus = null;
                            _foundCase = null;
                          }),
                  ),
                  TextField(
                    controller: _followUpCode,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: s('code')),
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                  ),
                  HistaeButton.outlined(
                    onPressed:
                        _busy ||
                            !RegExp(r'^[A-Za-z0-9_-]{43}$')
                                .hasMatch(_followUpCode.text.trim())
                        ? null
                        : () => _run(_lookup),
                    child: Text(s('check')),
                  ),
                  if (_erasureStatus case final status?) Text(s(status)),
                  if (_foundCase case final entry?) _card(entry, s),
                ],
                if (_hasList) ...[
                  const SizedBox(height: 12),
                  HistaeButton.text(
                    onPressed: _busy ? null : () => _run(() => _load()),
                    child: Text(s('refresh')),
                  ),
                  if (widget.view == CaseworkView.thread && _initial != null)
                    _entry(s('you'), _initial!),
                  for (final row
                      in widget.view == CaseworkView.thread
                          ? _rows.reversed
                          : _rows)
                    if (widget.view == CaseworkView.thread)
                      _entry(
                        s(row['author'] == 'team' ? 'team' : 'you'),
                        jsonString(row, 'body'),
                      )
                    else
                      _card(row, s),
                  if (!_busy &&
                      _rows.isEmpty &&
                      _initial == null &&
                      _error == null)
                    Text(s('empty')),
                  if (_before != null)
                    HistaeButton.outlined(
                      onPressed: _busy
                          ? null
                          : () => _run(() => _load(more: true)),
                      child: Text(s('more')),
                    ),
                ],
          if (widget.view == CaseworkView.thread && _canReply)
                  _compose(s),
                if (_exportId case final id?)
                  HistaeButton.outlined(
                    onPressed: () => widget.openExport?.call(id),
                    child: Text(s('assistedExport')),
                  ),
              ],
            ),
    );
  }

  Widget _supportForm(String Function(String) s) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: InputDecoration(labelText: s('category')),
        items: [
          for (final category in [
            'login',
            'billing',
            'appeal',
            'privacy',
            'other',
          ])
            DropdownMenuItem(value: category, child: Text(s(category))),
        ],
        onChanged: _busy
            ? null
            : (value) => setState(() => _category = value ?? _category),
      ),
      _compose(s),
    ],
  );

  Widget _compose(String Function(String) s) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _message,
        minLines: 3,
        maxLines: 8,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: s('message'),
          helperText: s('limit'),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      HistaeButton(
        onPressed: _busy || !_validMessage ? null : () => _run(_send),
        child: Text(s('send')),
      ),
    ],
  );

  Widget _card(Map<String, dynamic> entry, String Function(String) s) {
    return _entry(
      '${s(optionalText(entry, 'reason') ?? optionalText(entry, 'category') ?? 'other')} · ${s(jsonString(entry, 'status'))}',
      optionalText(entry, 'body') ?? optionalText(entry, 'description') ?? '',
      response: optionalText(entry, 'response'),
      team: s('team'),
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
