import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../data/privacy_models.dart';
import '../data/privacy_repository.dart';
import '../data/private_export_store.dart';

enum PrivacySection { sessions, blocks, rights, export, deletion }

class PrivacyController extends ChangeNotifier {
  PrivacyController(this.repository, {PrivateExportStore? exportStore})
    : exportStore = exportStore ?? PrivateExportStore() {
    _key = session.resourceKey;
    session.addListener(_sessionChanged);
  }
  final PrivacyRepository repository;
  final PrivateExportStore exportStore;
  SessionController get session => repository.session;
  late String _key;
  bool _disposed = false, _active = true;
  int _epoch = 0;
  RequestCancellation _scope = RequestCancellation();
  Timer? _cooldown;
  DateTime? _retryAt;
  PrivacySection? section;
  final sessions = <MobileSession>[],
      blocks = <BlockedPerson>[],
      rights = <RightsRequest>[];
  String? cursor, pendingRevoke, pendingUnblock, exportPath;
  DataRight? pendingRight;
  bool loading = false,
      busy = false,
      deleting = false,
      sharing = false,
      _sharePendingCleanup = false;
  ApiFailure? failure;
  String? notice;
  bool get accessible =>
      !_disposed &&
      session.hasSession &&
      [SessionPhase.ready, SessionPhase.needsConsents].contains(session.phase);
  bool get onboarded => accessible && session.phase == SessionPhase.ready;
  bool get active => accessible && _active;
  int get retrySeconds {
    final ms = _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool _alive(int epoch) => active && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (accessible && _key == session.resourceKey) return;
    _key = session.resourceKey;
    suspend(notify: false, forceClean: true);
    sessions.clear();
    blocks.clear();
    rights.clear();
    cursor = null;
    pendingRevoke = null;
    pendingUnblock = null;
    pendingRight = null;
    failure = null;
    notice = null;
    _retryAt = null;
    _cooldown?.cancel();
    _notify();
  }

  void _error(ApiFailure e) {
    failure = e;
    if (e.retryAt != null &&
        (_retryAt == null || e.retryAt!.isAfter(_retryAt!))) {
      _retryAt = e.retryAt;
    }
    if (retrySeconds > 0) {
      _cooldown?.cancel();
      _cooldown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (retrySeconds == 0) t.cancel();
        _notify();
      });
    }
    if (e.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  Future<void> _cleanExport() async {
    exportPath = null;
    try {
      await exportStore.clean();
    } catch (_) {
      if (!_disposed) {
        failure = const ApiFailure(
          ApiFailureKind.unavailable,
          code: 'export_cleanup',
        );
        _notify();
      }
    }
  }

  Future<void> start() async {
    await _cleanExport();
  }

  void suspend({bool notify = true, bool forceClean = false}) {
    _active = false;
    _epoch++;
    _scope.cancel();
    loading = false;
    busy = false;
    if (!sharing || forceClean) unawaited(_cleanExport());
    if (notify) _notify();
  }

  Future<void> resume() async {
    await session.synchronize();
    if (!accessible) return;
    _active = true;
    _scope = RequestCancellation();
    if (_sharePendingCleanup && !sharing) {
      _sharePendingCleanup = false;
      await _cleanExport();
    }
    await load();
  }

  Future<void> enter(PrivacySection value) async {
    if (section != value && !busy && !sharing) {
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      loading = false;
      if (section == PrivacySection.export) await _cleanExport();
    }
    section = value;
    if (!active && accessible) {
      _active = true;
      _scope = RequestCancellation();
    }
    failure = null;
    notice = null;
    await load();
  }

  Future<void> clearExport() async {
    if (!busy && !sharing) {
      await _cleanExport();
      _notify();
    }
  }

  void leave(PrivacySection value) {
    if (section != value) return;
    section = null;
    _epoch++;
    _scope.cancel();
    _scope = RequestCancellation();
    loading = false;
    busy = false;
    if (value == PrivacySection.export) unawaited(_cleanExport());
  }

  Future<void> load({bool more = false}) async {
    if (!active || loading || busy || retrySeconds > 0 || section == null) {
      return;
    }
    if (section == PrivacySection.blocks && !onboarded) return;
    if (![
      PrivacySection.sessions,
      PrivacySection.blocks,
      PrivacySection.rights,
    ].contains(section)) {
      _notify();
      return;
    }
    final epoch = _epoch, current = section;
    loading = true;
    failure = null;
    _notify();
    try {
      if (current == PrivacySection.sessions) {
        final result = <MobileSession>[],
            seen = <String>{},
            cursors = <String>{};
        var next = more ? cursor : null;
        do {
          final page = await repository.sessions(_scope, cursor: next);
          if (!_alive(epoch) || section != current) return;
          for (final item in page.items) {
            if (seen.add(item.id)) result.add(item);
          }
          next = page.cursor;
          if (next != null && !cursors.add(next)) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
        } while (!more &&
            pendingRevoke != null &&
            !seen.contains(pendingRevoke) &&
            next != null);
        if (!more) sessions.clear();
        final ids = sessions.map((s) => s.id).toSet();
        sessions.addAll(result.where((s) => ids.add(s.id)));
        cursor = next;
        if (pendingRevoke != null &&
            (seen.contains(pendingRevoke) == false && next == null)) {
          pendingRevoke = null;
        }
      } else if (current == PrivacySection.blocks) {
        final list = await repository.blocks(_scope);
        if (!_alive(epoch) || section != current) return;
        blocks
          ..clear()
          ..addAll(list);
        if (pendingUnblock != null &&
            !blocks.any((b) => b.id == pendingUnblock)) {
          pendingUnblock = null;
        }
      } else {
        final list = await repository.rights(_scope);
        if (!_alive(epoch) || section != current) return;
        rights
          ..clear()
          ..addAll(list);
        if (pendingRight != null &&
            rights.any((r) => r.type == pendingRight && r.open)) {
          pendingRight = null;
        }
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        _error(e);
        if (e.code == 'invalid_cursor') {
          cursor = null;
          sessions.clear();
        }
      }
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> revoke(MobileSession target) async {
    if (!active ||
        busy ||
        loading ||
        retrySeconds > 0 ||
        (pendingRevoke != null && pendingRevoke != target.id)) {
      return;
    }
    if (target.current) {
      await session.revokeCurrentSession(target.id);
      return;
    }
    pendingRevoke = target.id;
    await _change(() => repository.revoke(target.id, _scope), () {
      pendingRevoke = null;
      notice = 'session_revoked';
    });
  }

  Future<void> unblock(String id) async {
    if (!onboarded ||
        !active ||
        busy ||
        loading ||
        retrySeconds > 0 ||
        (pendingUnblock != null && pendingUnblock != id)) {
      return;
    }
    pendingUnblock = id;
    await _change(() => repository.block(id, false, _scope), () {
      pendingUnblock = null;
      notice = 'unblocked';
    });
  }

  Future<void> request(DataRight type) async {
    if (!active ||
        busy ||
        loading ||
        retrySeconds > 0 ||
        (pendingRight != null && pendingRight != type)) {
      return;
    }
    if (rights.any((r) => r.type == type && r.open)) {
      notice = 'request_open';
      _notify();
      return;
    }
    pendingRight = type;
    await _change(
      () async {
        final result = await repository.requestRight(type, _scope);
        if (result.type != type) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
      },
      () {
        pendingRight = null;
        notice = 'request_received';
      },
    );
  }

  Future<void> _change(
    Future<void> Function() action,
    void Function() success,
  ) async {
    final epoch = _epoch;
    busy = true;
    failure = null;
    notice = null;
    _notify();
    ApiFailure? error;
    try {
      await action();
      if (_alive(epoch)) success();
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        error = e;
        _error(e);
        if (e.code == 'data_request_already_open') {
          pendingRight = null;
          notice = 'request_open';
        }
        if (e.code == 'session_not_found') pendingRevoke = null;
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        await load();
        if (_alive(epoch) && error != null) failure = error;
        _notify();
      }
    }
  }

  Future<void> downloadExport() async {
    if (!active || busy || loading || sharing || retrySeconds > 0) return;
    final epoch = _epoch, scope = _scope;
    busy = true;
    failure = null;
    notice = null;
    _notify();
    try {
      await _cleanExport();
      if (!_alive(epoch)) return;
      final stream = await session.openDataExport(scope);
      final path = await exportStore.save(stream, scope);
      if (!_alive(epoch)) {
        await _cleanExport();
        return;
      }
      exportPath = path;
      notice = 'export_ready';
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _error(e);
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> shareExport(Future<void> Function(String path) share) async {
    final path = exportPath;
    if (!active || path == null || busy || sharing) return;
    sharing = true;
    _sharePendingCleanup = true;
    _notify();
    try {
      await share(path);
      if (accessible) notice = 'share_closed';
    } catch (_) {
      if (accessible) {
        _error(
          const ApiFailure(ApiFailureKind.unavailable, code: 'export_share'),
        );
      }
    } finally {
      sharing = false;
      if (_active || _disposed || !accessible) {
        _sharePendingCleanup = false;
        await _cleanExport();
      }
      _notify();
    }
  }

  Future<void> erase() async {
    if (!active || deleting || busy || retrySeconds > 0) return;
    final epoch = _epoch;
    deleting = true;
    busy = true;
    failure = null;
    _notify();
    try {
      final ticket = await repository.deletionTicket(_scope);
      if (!_alive(epoch)) return;
      if (!ticket.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const ApiFailure(
          ApiFailureKind.expired,
          code: 'invalid_or_expired_deletion_token',
        );
      }
      await session.eraseAccount(ticket.value);
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _error(e);
    } finally {
      if (!_disposed) {
        deleting = false;
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    suspend(notify: false, forceClean: true);
    _cooldown?.cancel();
    session.removeListener(_sessionChanged);
    sessions.clear();
    blocks.clear();
    rights.clear();
    super.dispose();
  }
}
