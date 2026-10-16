import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../../consents/data/consent_state.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository) {
    _key = session.resourceKey;
    session.addListener(_sessionChanged);
  }
  final ProfileRepository repository;
  SessionController get session => repository.session;
  OwnerProfile? profile;
  Preferences? preferences;
  List<ProfileTrait> traits = [], selectedTraits = [];
  List<ProfileQuestion> questions = [];
  List<ProfileAnswer> answers = [];
  final errors = <String, ApiFailure>{};
  bool loading = false, saving = false, uncertain = false;
  bool _disposed = false;
  int _generation = 0;
  late String _key;
  RequestCancellation _scope = RequestCancellation();
  Timer? _timer;
  PhotoIntent? photoIntent;
  DateTime? photoReadAt;
  bool get sensitiveAllowed =>
      session.consents?.consents.any(
        (c) => c.type == ConsentType.sensitive && c.current,
      ) ??
      false;
  bool get accessible =>
      !_disposed && session.hasSession && session.phase == SessionPhase.ready;
  bool get canWrite =>
      accessible && !saving && !loading && !uncertain && retrySeconds == 0;
  DateTime? retryAt;
  int get retrySeconds {
    final ms = retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_key == session.resourceKey && accessible) return;
    _key = session.resourceKey;
    _generation++;
    _scope.cancel();
    _scope = RequestCancellation();
    profile = null;
    preferences = null;
    traits = [];
    selectedTraits = [];
    questions = [];
    answers = [];
    _discardIntent();
    photoReadAt = null;
    errors.clear();
    loading = false;
    saving = false;
    uncertain = false;
    retryAt = null;
    _timer?.cancel();
    _notify();
    if (accessible) unawaited(load());
  }

  void _cooldown(ApiFailure e) {
    if (e.retryAt != null &&
        (retryAt == null || e.retryAt!.isAfter(retryAt!))) {
      retryAt = e.retryAt;
    }
    if (retrySeconds > 0) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (retrySeconds == 0) t.cancel();
        _notify();
      });
    }
  }

  Future<void> load() async {
    if (_disposed || !accessible || loading || saving || retrySeconds > 0) {
      return;
    }
    final generation = _generation;
    final scope = _scope;
    loading = true;
    _notify();
    Future<void> read<T>(
      String section,
      Future<T> Function() fetch,
      void Function(T) assign,
    ) async {
      try {
        final result = await fetch();
        if (_disposed || generation != _generation || scope.isCancelled) return;
        assign(result);
        errors.remove(section);
      } on ApiFailure catch (e) {
        if (_disposed || generation != _generation) return;
        errors[section] = e;
        _cooldown(e);
        if (e.kind == ApiFailureKind.consentRequired) {
          unawaited(session.synchronize());
        }
      }
    }

    await Future.wait([
      read('profile', () => repository.profile(scope), (p) {
        profile = p;
        photoReadAt = DateTime.now();
      }),
      read(
        'preferences',
        () => repository.preferences(scope),
        (p) => preferences = p,
      ),
      read('traits', () => repository.traits(scope), (v) => traits = v),
      read(
        'selectedTraits',
        () => repository.selectedTraits(scope),
        (v) => selectedTraits = v,
      ),
      read(
        'questions',
        () => repository.questions(scope),
        (v) => questions = v,
      ),
      read('answers', () => repository.answers(scope), (v) => answers = v),
    ]);
    if (_disposed || generation != _generation) return;
    loading = false;
    if (errors.isEmpty) uncertain = false;
    _notify();
  }

  Future<void> mutate(
    Future<void> Function() action, {
    bool photo = false,
  }) async {
    if (!canWrite) throw const ApiFailure(ApiFailureKind.conflict);
    final generation = _generation;
    saving = true;
    _notify();
    try {
      await action();
      if (_disposed || generation != _generation || !accessible) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      if (photo) {
        _discardIntent();
        profile = null;
        photoReadAt = null;
      }
    } on ApiFailure catch (e) {
      if (!_disposed && generation == _generation) {
        _cooldown(e);
        uncertain = [
          ApiFailureKind.network,
          ApiFailureKind.timeout,
          ApiFailureKind.server,
          ApiFailureKind.invalidResponse,
          ApiFailureKind.unavailable,
        ].contains(e.kind);
        if (photo &&
            (e.code == 'idempotency_key_consumed' ||
                e.code == 'idempotency_key_conflict' ||
                e.kind == ApiFailureKind.expired)) {
          _discardIntent();
          uncertain = true;
        }
        if (e.kind == ApiFailureKind.consentRequired) {
          unawaited(session.synchronize());
        }
      }
      rethrow;
    } finally {
      if (!_disposed && generation == _generation) {
        saving = false;
        _notify();
      }
    }
    await load();
  }

  Future<void> upload() async {
    final intent = photoIntent;
    if (intent == null) throw const ApiFailure(ApiFailureKind.validation);
    // Explicit resume with the identical intent is allowed after an uncertain
    // upload, even before a full read succeeds. No new key is generated here.
    if (uncertain && accessible && !saving && !loading && retrySeconds == 0) {
      uncertain = false;
    }
    await mutate(() => repository.upload(intent), photo: true);
  }

  void setPhoto(List<int>? bytes) {
    _discardIntent();
    photoIntent = bytes == null ? null : PhotoIntent(bytes);
    _notify();
  }

  void _discardIntent() {
    if (photoIntent case final intent?) {
      unawaited(MemoryImage(intent.bytes).evict());
    }
    photoIntent = null;
  }

  void clearPhotoPreview() {
    photoReadAt = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _scope.cancel();
    _timer?.cancel();
    session.removeListener(_sessionChanged);
    profile = null;
    preferences = null;
    traits = [];
    selectedTraits = [];
    questions = [];
    answers = [];
    _discardIntent();
    super.dispose();
  }
}
