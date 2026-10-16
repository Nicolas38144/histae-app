import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/application/session_controller.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this.session);
  final SessionController session;
  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    List<int>? photo,
    String? key,
    int status = 200,
    RequestCancellation? cancellation,
  }) => session.request(
    method,
    path,
    body: body,
    photo: photo,
    idempotencyKey: key,
    expectedStatus: status,
    replayAfterRefresh: true,
    cancellation: cancellation,
  );
  // An expired-access 401 is a definitive rejection before mutation. This is the
  // only automatic replay; lost responses always return control to the user.
  Future<OwnerProfile?> profile(RequestCancellation scope) async {
    try {
      final p = OwnerProfile.fromJson(
        await _request('GET', '/api/users/me', cancellation: scope),
      );
      if (p.userId != session.identity?.userId) invalidProfile();
      return p;
    } on ApiFailure catch (e) {
      if (e.statusCode == 404 && e.code == 'profile_not_found') return null;
      rethrow;
    }
  }

  Future<Preferences?> preferences(RequestCancellation scope) async {
    try {
      final value = jsonObject(
        await _request('GET', '/api/users/me/preferences', cancellation: scope),
      );
      if (serverId(value, 'user_id') != session.identity?.userId) {
        invalidProfile();
      }
      return Preferences.fromJson(value);
    } on ApiFailure catch (e) {
      if (e.statusCode == 404 && e.code == 'preferences_not_found') return null;
      rethrow;
    }
  }

  Future<List<T>> _list<T>(
    String path,
    String field,
    T Function(Object?) parse,
    RequestCancellation scope,
  ) async => List<T>.unmodifiable(
    jsonField<List<dynamic>>(
      jsonObject(await _request('GET', path, cancellation: scope)),
      field,
    ).map(parse),
  );
  Future<List<ProfileTrait>> traits(RequestCancellation s) =>
      _list('/api/traits', 'traits', ProfileTrait.fromJson, s);
  Future<List<ProfileTrait>> selectedTraits(RequestCancellation s) =>
      _list('/api/users/me/traits', 'traits', ProfileTrait.fromJson, s);
  Future<List<ProfileQuestion>> questions(RequestCancellation s) =>
      _list('/api/profile-questions', 'questions', ProfileQuestion.fromJson, s);
  Future<List<ProfileAnswer>> answers(RequestCancellation s) => _list(
    '/api/users/me/profile-answers',
    'answers',
    ProfileAnswer.fromJson,
    s,
  );
  Future<void> saveProfile(ProfileDraft draft) async {
    if (draft.validate(DateTime.now()) != null) {
      throw const ApiFailure(ApiFailureKind.validation);
    }
    await _request('PATCH', '/api/users/me/profile', body: draft.toJson());
  }

  Future<void> savePreferences(Preferences p) async {
    if (p.validate() != null) throw const ApiFailure(ApiFailureKind.validation);
    await _request('PATCH', '/api/users/me/preferences', body: p.toJson());
  }

  Future<void> setTrait(String id, bool selected) async {
    serverId({'id': id}, 'id');
    await _request(
      selected ? 'POST' : 'DELETE',
      selected ? '/api/users/me/traits' : '/api/users/me/traits/$id',
      body: selected ? {'traitId': id} : null,
      status: 204,
    );
  }

  Future<void> saveAnswers(List<AnswerDraft> answers) async {
    if (answers.length > 3 ||
        answers.map((a) => a.questionId).toSet().length != answers.length ||
        answers.any((a) => a.validate() != null)) {
      throw const ApiFailure(ApiFailureKind.validation);
    }
    for (final answer in answers) {
      serverId({'id': answer.questionId}, 'id');
    }
    final j = jsonObject(
      await _request(
        'PUT',
        '/api/users/me/profile-answers',
        body: {'answers': answers.map((a) => a.toJson()).toList()},
      ),
    );
    jsonField<List<dynamic>>(j, 'answers').map(ProfileAnswer.fromJson).toList();
  }

  Future<void> upload(PhotoIntent intent) async {
    if (intent.expired) throw const ApiFailure(ApiFailureKind.expired);
    final j = jsonObject(
      await _request(
        'PUT',
        '/api/users/me/photo',
        photo: intent.bytes,
        key: intent.key,
      ),
    );
    if (!validPhotoUrl(jsonString(j, 'photo'))) invalidProfile();
    Moderation.parse(
      jsonString(j, 'moderation_status'),
      j['moderation_reasons'],
    );
  }

  Future<void> removePhoto() async {
    await _request('DELETE', '/api/users/me/photo', status: 204);
  }
}

class PhotoIntent {
  PhotoIntent(List<int> bytes, {DateTime? createdAt, String? key})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      createdAt = createdAt ?? DateTime.now().toUtc(),
      key = key ?? newUuidV4() {
    if (bytes.isEmpty || bytes.length > 500000) {
      throw const ApiFailure(ApiFailureKind.payloadTooLarge);
    }
  }
  final Uint8List bytes;
  final String key;
  final DateTime createdAt;
  bool get expired =>
      DateTime.now().toUtc().difference(createdAt) >= const Duration(hours: 24);
}
