import '../../../core/network/api_failure.dart';
import '../../auth/domain/authenticated_session.dart';
import 'realtime_client.dart';

/// One transport per authenticated session, with independently owned listeners.
/// Route handoffs keep the connection; hidden flows stop receiving signals.
final class RealtimeHub {
  RealtimeHub(this.session) : _source = RealtimeClient(session) {
    _source.onSignal = (signal) {
      for (final client in _clients.toList()) {
        if (_clients.contains(client)) client.onSignal?.call(signal);
      }
    };
    _source.onState = (connected, failure) {
      _connected = connected;
      _failure = failure;
      for (final client in _clients.toList()) {
        if (_clients.contains(client)) {
          client.onState?.call(connected, failure);
        }
      }
    };
  }

  final AuthenticatedSession session;
  final RealtimeClient _source;
  final _clients = <_RealtimeChannel>{};
  bool _disposed = false;
  bool _connected = false;
  ApiFailure? _failure;

  RealtimeClient channel() => _RealtimeChannel(this);

  void _start(_RealtimeChannel client) {
    if (_disposed || session.phase != SessionPhase.ready) return;
    _clients.add(client);
    client.onState?.call(_connected, _failure);
    _source.start();
  }

  void reset() {
    _clients.clear();
    _connected = false;
    _failure = null;
    _source.stop();
  }

  void dispose() {
    _disposed = true;
    _clients.clear();
    _source.dispose();
  }
}

final class _RealtimeChannel extends RealtimeClient {
  _RealtimeChannel(this.hub) : super(hub.session);
  final RealtimeHub hub;
  bool _disposed = false;

  @override
  void start() {
    if (!_disposed) hub._start(this);
  }

  @override
  void stop() => hub._clients.remove(this);

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
