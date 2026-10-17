import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../data/privacy_models.dart';
import '../data/privacy_repository.dart';

class ReportController extends ChangeNotifier {
  ReportController(this.repository, this.target, {this.matchId}) {
    _key = session.resourceKey;
    session.addListener(_changed);
  }
  final PrivacyRepository repository;
  final String target;
  final String? matchId;
  SessionController get session => repository.session;
  late final String _key;
  final _scope = RequestCancellation();
  Timer? _timer;
  DateTime? _retryAt;
  bool _disposed = false,
      sending = false,
      submitted = false,
      alreadyPending = false;
  ReportIntent? pending;
  ApiFailure? failure;
  String? validation;
  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.resourceKey == _key &&
      session.identity?.userId != target;
  int get retrySeconds {
    final ms = _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!accessible) {
      _scope.cancel();
      pending = null;
      failure = null;
      validation = null;
      _timer?.cancel();
      _notify();
    }
  }

  Future<void> submit(ReportReason reason, String description) async {
    if (!accessible || sending || submitted || retrySeconds > 0) return;
    validation = validateReport(description);
    if (pending == null && validation != null) {
      _notify();
      return;
    }
    pending ??= ReportIntent(target, matchId, reason, description);
    sending = true;
    failure = null;
    _notify();
    try {
      await repository.report(pending!, _scope);
      if (accessible) {
        submitted = true;
        pending = null;
      }
    } on ApiFailure catch (e) {
      if (accessible) {
        failure = e;
        if (e.code == 'report_already_pending') {
          submitted = true;
          alreadyPending = true;
          pending = null;
        }
        if ([
          'invalid_report_payload',
          'invalid_report_request',
          'account_not_found',
          'match_not_found',
        ].contains(e.code)) {
          pending = null;
        }
        _retryAt = e.retryAt;
        if (retrySeconds > 0) {
          _timer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (retrySeconds == 0) t.cancel();
            _notify();
          });
        }
        if (e.kind == ApiFailureKind.consentRequired) {
          unawaited(session.synchronize());
        }
      }
    } finally {
      sending = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scope.cancel();
    _timer?.cancel();
    pending = null;
    session.removeListener(_changed);
    super.dispose();
  }
}
