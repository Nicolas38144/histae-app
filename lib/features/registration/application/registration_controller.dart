import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../consents/domain/consent_state.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/data/profile_repository.dart';
import '../data/registration_legal_repository.dart';
import 'registration_draft.dart';

enum RegistrationStep { profile, preferences, consents, phone }

/// Coordinates the draft and authenticated writes; widgets never call the API.
class RegistrationController extends ChangeNotifier {
  RegistrationController(this.session, {ProfileRepository? profiles})
    : _profiles = profiles ?? ProfileRepository(session),
      _legal = RegistrationLegalRepository(session) {
    _language = session.language;
    session.addListener(_sessionChanged);
  }
  final SessionController session;
  final ProfileRepository _profiles;
  final RegistrationLegalRepository _legal;
  final draft = RegistrationDraft();
  RegistrationStep step = RegistrationStep.profile;
  List<PublicConsent> documents = const [];
  final _choices = <ConsentType, bool>{};
  ApiFailure? failure;
  bool loadingDocuments = false;
  bool saving = false;
  bool verified = false;
  bool existingAccount = false;
  bool completed = false;
  bool _disposed = false;
  bool _consentsSaved = false;
  bool _profileStarted = false;
  bool _profileSaved = false;
  bool _preferencesSaved = false;
  bool _documentsAvailable = false;
  DateTime? _retryAt;
  String? _owner;
  late ApiLanguage _language;
  RequestCancellation _scope = RequestCancellation();
  late final RetryTicker _retryTimer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: _notify,
  );

  int get retrySeconds {
    final own = retrySecondsUntil(_retryAt);
    return own > session.retrySeconds ? own : session.retrySeconds;
  }

  void _fail(ApiFailure error) {
    failure = error;
    if (error.retryAt case final deadline?) {
      if (_retryAt == null || deadline.isAfter(_retryAt!)) _retryAt = deadline;
    }
    _retryTimer.cancel();
    if (retrySeconds > 0) _retryTimer.restart();
  }

  bool choice(ConsentType type) => _choices[type] ?? false;
  bool get canVerify =>
      documents.length == 4 &&
      _documentsAvailable &&
      !loadingDocuments &&
      choice(ConsentType.terms) &&
      choice(ConsentType.privacy);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_disposed || session.language == _language) return;
    _language = session.language;
    // A submitted intent keeps its displayed documents. saveConsents performs
    // the authoritative comparison before writing, including language changes.
    if (saving || _consentsSaved) return;
    if (documents.isNotEmpty || loadingDocuments) {
      _choices.clear();
      _consentsSaved = false;
      if (step == RegistrationStep.phone) step = RegistrationStep.consents;
      unawaited(loadDocuments());
    }
  }

  void next() {
    if (saving) return;
    failure = null;
    switch (step) {
      case RegistrationStep.profile:
        step = RegistrationStep.preferences;
      case RegistrationStep.preferences:
        step = RegistrationStep.consents;
        if (documents.isEmpty && !loadingDocuments) unawaited(loadDocuments());
      case RegistrationStep.consents:
        if (canVerify) step = RegistrationStep.phone;
      case RegistrationStep.phone:
        return;
    }
    _notify();
  }

  void back() {
    if (saving || verified || step == RegistrationStep.profile) return;
    step = RegistrationStep.values[step.index - 1];
    failure = null;
    _notify();
  }

  void setChoice(ConsentType type, bool value) {
    if (saving || loadingDocuments) return;
    _choices[type] = value;
    failure = null;
    _notify();
  }

  Future<void> loadDocuments() async {
    if (_disposed || retrySeconds > 0) return;
    _scope.cancel();
    final scope = _scope = RequestCancellation();
    loadingDocuments = true;
    _documentsAvailable = false;
    failure = null;
    _notify();
    try {
      final next = await _legal.load(scope);
      if (_disposed || scope.isCancelled) return;
      final same =
          documents.length == next.length &&
          next.every(
            (document) => documents.any(
              (old) =>
                  old.type == document.type &&
                  old.requiredVersion == document.requiredVersion &&
                  old.documentUrl == document.documentUrl &&
                  old.documentLanguage == document.documentLanguage,
            ),
          );
      if (!same) _choices.clear();
      documents = next;
      _documentsAvailable = true;
    } on ApiFailure catch (error) {
      if (!_disposed && !scope.isCancelled) _fail(error);
    } finally {
      if (!_disposed && identical(scope, _scope)) {
        loadingDocuments = false;
        _notify();
      }
    }
  }

  Future<void> authenticate(TokenPair tokens) async {
    if (_disposed || saving || !canVerify) {
      try {
        await session.repository.logout(tokens);
      } on ApiFailure {
        /* Best effort for a verification completed after leaving its step. */
      }
      return;
    }
    saving = true;
    failure = null;
    _notify();
    try {
      await session.establish(tokens);
      if (_disposed) return;
      verified = session.hasSession;
      final owner = session.identity?.userId;
      if (_owner != null && owner != null && _owner != owner) {
        _consentsSaved = _profileStarted = _profileSaved = _preferencesSaved =
            false;
      }
      if (owner != null) _owner = owner;
      if (!verified || owner == null) {
        throw session.failure ??
            const ApiFailure(ApiFailureKind.unauthenticated);
      }
      // Registering with an existing number must never replace its profile.
      if (session.identity!.onboardingComplete) {
        existingAccount = true;
      } else {
        await _saveDraft();
      }
    } on ApiFailure catch (error) {
      if (!_disposed) _fail(error);
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> retrySave() async {
    if (_disposed ||
        saving ||
        !verified ||
        existingAccount ||
        !canVerify ||
        retrySeconds > 0) {
      return;
    }
    if (!session.hasSession) {
      verified = false;
      _consentsSaved = false;
      _notify();
      return;
    }
    saving = true;
    failure = null;
    _notify();
    try {
      if (session.phase == SessionPhase.unavailable) {
        await session.synchronize();
      }
      _owner ??= session.identity?.userId;
      await _saveDraft();
    } on ApiFailure catch (error) {
      if (!_disposed) _fail(error);
    } finally {
      saving = false;
      _notify();
    }
  }

  void _checkOwner() {
    if (_disposed ||
        !session.hasSession ||
        session.identity?.userId != _owner) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }

  Future<void> _saveDraft() async {
    _checkOwner();
    if (draft.profile.validate(DateTime.now()) != null ||
        draft.preferences.validate() != null) {
      throw const ApiFailure(ApiFailureKind.validation);
    }
    if (!_consentsSaved) {
      try {
        await session.saveConsents(
          {
            for (final document in documents)
              if (choice(document.type)) document.type: true,
          },
          {
            for (final document in documents)
              document.type: document.requiredVersion,
          },
          displayedDocuments: {
            for (final document in documents) document.type: document,
          },
        );
      } on ApiFailure catch (error) {
        if (error.code == 'legal_documents_changed') {
          _choices.clear();
          step = RegistrationStep.consents;
          await loadDocuments();
        }
        rethrow;
      }
      _checkOwner();
      _consentsSaved = true;
    }
    final sensitive =
        choice(ConsentType.sensitive) &&
        (session.consents?.consents.any(
              (c) => c.type == ConsentType.sensitive && c.current,
            ) ??
            false);
    final profile = draft.profile;
    final intended = ProfileDraft(
      profile.firstname,
      profile.birthdate,
      sensitive ? profile.sex : null,
      profile.bio,
    );
    if (!_profileSaved) {
      final current = await _profiles.profile(_scope);
      _checkOwner();
      if (current != null && !_profileStarted) {
        existingAccount = true;
        return;
      }
      final matches =
          current != null &&
          current.firstname == intended.firstname.trim() &&
          current.birthdate == intended.birthdate &&
          current.sex == intended.sex &&
          current.bio == intended.bio?.trim();
      if (!matches) {
        _profileStarted = true;
        await _profiles.saveProfile(intended);
      }
      _checkOwner();
      _profileSaved = true;
    }
    if (sensitive && !_preferencesSaved) {
      final current = await _profiles.preferences(_scope);
      _checkOwner();
      final intended = draft.preferences;
      final matches =
          current != null &&
          current.minAge == intended.minAge &&
          current.maxAge == intended.maxAge &&
          current.distance == intended.distance &&
          current.lookingFor == intended.lookingFor;
      if (!matches) await _profiles.savePreferences(intended);
      _checkOwner();
      _preferencesSaved = true;
    }
    completed = true;
  }

  @override
  void dispose() {
    _disposed = true;
    _scope.cancel();
    _retryTimer.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
