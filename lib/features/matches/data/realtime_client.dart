import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../../discovery/data/discovery_models.dart' show wireTime;
import '../../profile/data/profile_models.dart';

class MobileSignal {
  const MobileSignal(
    this.type, {
    this.id,
    this.matchId,
    this.ended = false,
    this.serverTime,
  });
  final String type;
  final String? id, matchId;
  final bool ended;
  final DateTime? serverTime;
}

// Bounded UTF-8 frame decoder: CR/LF/CRLF, chunk boundaries, comments and
// multiline data. Incomplete frames are discarded on disconnect, never replayed.
class MobileEventDecoder {
  String _line = '', _event = '', _id = '';
  final _data = <String>[];
  int _size = 0;
  bool _cr = false, _first = true;
  List<MobileSignal> add(String text) {
    final signals = <MobileSignal>[];
    for (final c in text.codeUnits) {
      if (_first) {
        _first = false;
        if (c == 0xfeff) continue;
      }
      if (c == 10 && _cr) {
        _cr = false;
        continue;
      }
      _cr = c == 13;
      if (c == 10 || c == 13) {
        final signal = _consumeLine();
        if (signal != null) signals.add(signal);
      } else {
        _line += String.fromCharCode(c);
        if (_line.length > 16384) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
      }
    }
    return signals;
  }

  MobileSignal? _consumeLine() {
    final line = _line;
    _line = '';
    if (line.isEmpty) {
      final event = _event, id = _id, data = _data.join('\n');
      _event = '';
      _id = '';
      _data.clear();
      _size = 0;
      if (data.isEmpty) return null;
      const accepted = {
        'connected',
        'heartbeat',
        'match.created',
        'match.updated',
        'matches.invalidated',
        'message.created',
        'message.read',
        'subscription.updated',
      };
      if (!accepted.contains(event)) return null;
      try {
        final j = jsonDecode(data);
        if (j is! Map<String, dynamic>) invalidProfile();
        if (event == 'connected' || event == 'heartbeat') {
          return MobileSignal(event, serverTime: wireTime(j['server_time']));
        }
        final matchId = j['match_id'] == null ? null : serverId(j, 'match_id');
        return MobileSignal(
          event,
          id: id.isEmpty ? null : id,
          matchId: matchId,
          ended: event == 'match.updated' && j['status'] == 'ended',
        );
      } on FormatException {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
    }
    if (line.startsWith(':')) return null;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        if (value.length > 100) invalidProfile();
        _event = value;
      case 'id':
        if (value.length > 128 || value.contains('\u0000')) invalidProfile();
        _id = value;
      case 'data':
        _size += value.length;
        if (_size > 65536) invalidProfile();
        _data.add(value);
    }
    return null;
  }
}

class RealtimeClient {
  RealtimeClient(
    this.session, {
    Future<ApiEventStream> Function(RequestCancellation)? open,
  }) : _open = open ?? session.openEvents;
  final SessionController session;
  final Future<ApiEventStream> Function(RequestCancellation) _open;
  final _recent = <String>{};
  RequestCancellation _life = RequestCancellation();
  ApiEventStream? _connection;
  Future<void>? _running;
  bool _wanted = false, _disposed = false;
  void Function(MobileSignal)? onSignal;
  void Function(bool, ApiFailure?)? onState;
  void start() {
    if (_disposed ||
        !session.hasSession ||
        session.phase != SessionPhase.ready) {
      return;
    }
    _wanted = true;
    if (_running != null) return;
    _life = RequestCancellation();
    final task = _run(_life);
    _running = task;
    unawaited(
      task.whenComplete(() {
        _running = null;
        if (_wanted && !_disposed) start();
      }),
    );
  }

  Future<void> _run(RequestCancellation life) async {
    var failures = 0;
    while (_wanted && !life.isCancelled && !_disposed && session.hasSession) {
      ApiFailure? failure;
      final started = DateTime.now();
      try {
        final stream = await _open(life);
        _connection = stream;
        if (life.isCancelled || !_wanted) {
          stream.close();
          break;
        }
        final decoder = MobileEventDecoder();
        await for (final chunk in stream.bytes.transform(utf8.decoder)) {
          if (life.isCancelled || !_wanted || _disposed) break;
          for (final signal in decoder.add(chunk)) {
            if (signal.id case final id?) {
              if (!_recent.add(id)) continue;
              if (_recent.length > 128) _recent.remove(_recent.first);
            }
            if (signal.type == 'connected') onState?.call(true, null);
            onSignal?.call(signal);
          }
        }
      } on ApiFailure catch (e) {
        failure = e;
      } catch (_) {
        failure = const ApiFailure(ApiFailureKind.network);
      } finally {
        _connection?.close();
        _connection = null;
      }
      if (life.isCancelled || !_wanted || _disposed) break;
      onState?.call(false, failure);
      if (failure?.kind == ApiFailureKind.consentRequired) {
        _wanted = false;
        unawaited(session.synchronize());
        break;
      }
      if (!session.hasSession) break;
      failures = DateTime.now().difference(started).inSeconds >= 25
          ? 0
          : (failures + 1).clamp(0, 5);
      final backoff = Duration(
        milliseconds: 1000 * (1 << failures) + Random().nextInt(500),
      );
      final retry =
          failure?.retryAt?.difference(DateTime.now()) ?? Duration.zero;
      final elapsed = Completer<void>();
      final timer = Timer(retry > backoff ? retry : backoff, elapsed.complete);
      try {
        await Future.any([elapsed.future, life.whenCancelled]);
      } finally {
        timer.cancel();
      }
    }
  }

  void stop() {
    _wanted = false;
    _life.cancel();
    _connection?.close();
    _recent.clear();
  }

  void dispose() {
    _disposed = true;
    stop();
    onSignal = null;
    onState = null;
  }
}
