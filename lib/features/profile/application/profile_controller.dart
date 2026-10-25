import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/read_snapshots.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../consents/domain/consent_state.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'profile_feed_preview.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository) {
    _key = session.resourceKey;
    _localeRevision = session.localizationRevision;
    session.addListener(_sessionChanged);
  }
  final ProfileRepository repository;

  AuthenticatedSession get session => repository.session;
  OwnerProfile? profile;
  Preferences? preferences;
  List<ProfileTrait> _traits = [], _selectedTraits = [];
  List<ProfileQuestion> _questions = [];
  List<ProfileAnswer> _answers = [];
  final _errors = <String, ApiFailure>{};
  bool loading = false, saving = false, uncertain = false;
  bool _disposed = false;
  int _generation = 0, _readRevision = 0;
  late int _localeRevision;
  bool _languageDirty = false;
  late String _key;
  RequestCancellation _scope = RequestCancellation();
  late final RetryTicker _timer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  int photoRevision = 0;
  PhotoIntent? photoIntent;
  DateTime? photoReadAt;

  bool get sensitiveAllowed =>
      session.consents?.consents.any(
        (c) => c.type == ConsentType.sensitive && c.current,
      ) ??
      false;

  List<ProfileTrait> get traits => List.unmodifiable(_traits);

  List<ProfileTrait> get selectedTraits => List.unmodifiable(_selectedTraits);

  List<ProfileQuestion> get questions => List.unmodifiable(_questions);

  List<ProfileAnswer> get answers => List.unmodifiable(_answers);

  Map<String, ApiFailure> get errors => Map.unmodifiable(_errors);

  bool get accessible =>
      !_disposed && session.hasSession && session.phase == SessionPhase.ready;

  bool get canWrite =>
      accessible && !saving && !loading && !uncertain && retrySeconds == 0;
  DateTime? retryAt;

  int get retrySeconds => retrySecondsUntil(retryAt);

  bool get hasFeedPreview =>
      accessible &&
      profile != null &&
      !['profile', 'answers', 'selectedTraits'].any(_errors.containsKey);

  ProfileFeedPreview? feedPreviewAt(DateTime now) => hasFeedPreview
      ? ProfileFeedPreview.fromProfile(
          profile: profile!,
          traits: _selectedTraits,
          answers: _answers,
          now: now,
        )
      : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_key == session.resourceKey && accessible) {
      if (_localeRevision != session.localizationRevision) {
        _localeRevision = session.localizationRevision;
        _readRevision++;
        _scope.cancel();
        _scope = RequestCancellation();
        loading = false;
        _languageDirty = true;
        if (!saving) unawaited(load());
      }
      return;
    }
    _key = session.resourceKey;
    _localeRevision = session.localizationRevision;
    _generation++;
    _scope.cancel();
    _scope = RequestCancellation();
    profile = null;
    preferences = null;
    _traits = [];
    _selectedTraits = [];
    _questions = [];
    _answers = [];
    _discardIntent();
    photoReadAt = null;
    _errors.clear();
    loading = false;
    saving = false;
    uncertain = false;
    retryAt = null;
    _timer.cancel();
    _notify();
  }

  void _cooldown(ApiFailure e) {
    if (e.retryAt != null &&
        (retryAt == null || e.retryAt!.isAfter(retryAt!))) {
      retryAt = e.retryAt;
    }
    if (retrySeconds > 0) {
      _timer.cancel();
      _timer.restart();
    }
  }

  Future<void> ensureLoaded() => load(policy: ReadPolicy.cached);

  Future<void> load({ReadPolicy policy = ReadPolicy.refresh}) async {
    if (_disposed || !accessible || loading || saving || retrySeconds > 0) {
      return;
    }
    _languageDirty = false;
    final generation = _generation;
    final readRevision = ++_readRevision;
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
        if (_disposed ||
            generation != _generation ||
            readRevision != _readRevision ||
            scope.isCancelled) {
          return;
        }
        assign(result);
        _errors.remove(section);
      } on ApiFailure catch (e) {
        if (_disposed || generation != _generation) return;
        if (readRevision != _readRevision) return;
        _errors[section] = e;
        _cooldown(e);
        if (e.kind == ApiFailureKind.consentRequired) {
          unawaited(session.synchronize());
        }
      }
    }

    await Future.wait([
      read('profile', () => repository.profile(scope, policy: policy), (p) {
        profile = p;
        photoReadAt = repository.profileReadAt;
      }),
      read(
        'preferences',
        () => repository.preferences(scope, policy: policy),
        (p) => preferences = p,
      ),
      read(
        'traits',
        () => repository.traits(scope, policy: policy),
        (v) => _traits = v,
      ),
      read(
        'selectedTraits',
        () => repository.selectedTraits(scope, policy: policy),
        (v) => _selectedTraits = v,
      ),
      read(
        'questions',
        () => repository.questions(scope, policy: policy),
        (v) => _questions = v,
      ),
      read(
        'answers',
        () => repository.answers(scope, policy: policy),
        (v) => _answers = v,
      ),
    ]);
    if (_disposed || generation != _generation) return;
    if (readRevision != _readRevision) return;
    loading = false;
    if (_errors.isEmpty) uncertain = false;
    _notify();
  }

  String questionPrompt(String id, String fallback) {
    for (final question in _questions) {
      if (question.id == id) return question.prompt;
    }
    return fallback;
  }

  Future<void> saveIdentity(ProfileDraft draft) =>
      mutate(() => repository.saveProfile(draft));

  Future<void> savePreferences(Preferences preferences) =>
      mutate(() => repository.savePreferences(preferences));

  Future<void> setTrait(String id, bool selected) =>
      mutate(() => repository.setTrait(id, selected));

  Future<void> saveAnswers(List<AnswerDraft> drafts) =>
      mutate(() => repository.saveAnswers(drafts));

  Future<void> removePhoto() async {
    await mutate(repository.removePhoto, photo: true);
    setPhoto(null);
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
        if (photo) photoRevision++;
        _notify();
        if (_languageDirty) {
          _localeRevision = session.localizationRevision;
          unawaited(load());
        }
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

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _scope.cancel();
    _timer.cancel();
    session.removeListener(_sessionChanged);
    profile = null;
    preferences = null;
    _traits = [];
    _selectedTraits = [];
    _questions = [];
    _answers = [];
    _discardIntent();
    super.dispose();
  }
}
