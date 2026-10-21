import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'profile_models.dart';

abstract interface class ProfileRepository {
  factory ProfileRepository(
    AuthenticatedSession session, {
    ReadSnapshots? cache,
  }) = ApiProfileRepository;

  AuthenticatedSession get session;
  DateTime? get profileReadAt;

  Future<OwnerProfile?> profile(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<Preferences?> preferences(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<List<ProfileTrait>> traits(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<List<ProfileTrait>> selectedTraits(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<List<ProfileQuestion>> questions(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<List<ProfileAnswer>> answers(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<void> saveProfile(ProfileDraft draft);

  Future<void> savePreferences(Preferences preferences);

  Future<void> setTrait(String id, bool selected);

  Future<void> saveAnswers(List<AnswerDraft> answers);

  Future<void> upload(PhotoIntent intent);

  Future<void> removePhoto();
}

final class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this.session, {ReadSnapshots? cache})
    : _reads = cache ?? ReadSnapshots();
  final ReadSnapshots _reads;
  String get _scopeKey => '${session.resourceKey}:${session.language.code}';
  @override
  final AuthenticatedSession session;
  @override
  DateTime? get profileReadAt => _reads.readAt(DataResource.profile);

  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    List<int>? photo,
    String? key,
    int status = 200,
    RequestCancellation? cancellation,
  }) => method == 'GET'
      ? session.request(
          method,
          path,
          body: body,
          photo: photo,
          idempotencyKey: key,
          expectedStatus: status,
          replayAfterRefresh: true,
          cancellation: cancellation,
        )
      : _reads.mutate(
          _affected(path),
          () => session.request(
            method,
            path,
            body: body,
            photo: photo,
            idempotencyKey: key,
            expectedStatus: status,
            replayAfterRefresh: true,
            cancellation: cancellation,
          ),
        );

  Set<Object> _affected(String path) => switch (path) {
    '/api/users/me/preferences' => {DataResource.preferences},
    '/api/users/me/profile-answers' => {DataResource.answers},
    _ when path.startsWith('/api/users/me/traits') => {
      DataResource.selectedTraits,
    },
    _ => {DataResource.profile},
  };
  // An expired-access 401 is a definitive rejection before mutation. This is the
  // only automatic replay; lost responses always return control to the user.

  @override
  Future<OwnerProfile?> profile(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.profile,
    policy: policy,
    tags: {DataResource.profile},
    cancellation: scope,
    fetch: () => _fetchProfile(scope),
  );

  Future<OwnerProfile?> _fetchProfile(RequestCancellation scope) async {
    try {
      final p = OwnerProfile.fromJson(
        await _request('GET', '/api/users/me', cancellation: scope),
      );
      if (p.userId != session.identity?.userId) invalidResponse();
      return p;
    } on ApiFailure catch (e) {
      if (e.statusCode == 404 && e.code == 'profile_not_found') return null;
      rethrow;
    }
  }

  @override
  Future<Preferences?> preferences(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.preferences,
    policy: policy,
    tags: {DataResource.preferences},
    cancellation: scope,
    fetch: () => _fetchPreferences(scope),
  );

  Future<Preferences?> _fetchPreferences(RequestCancellation scope) async {
    try {
      final value = jsonObject(
        await _request('GET', '/api/users/me/preferences', cancellation: scope),
      );
      if (serverId(value, 'user_id') != session.identity?.userId) {
        invalidResponse();
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

  @override
  Future<List<ProfileTrait>> traits(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.traits,
    policy: policy,
    tags: {DataResource.traits},
    cancellation: scope,
    fetch: () => _fetchTraits(scope),
  );

  Future<List<ProfileTrait>> _fetchTraits(RequestCancellation s) =>
      _list('/api/traits', 'traits', ProfileTrait.fromJson, s);

  @override
  Future<List<ProfileTrait>> selectedTraits(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.selectedTraits,
    policy: policy,
    tags: {DataResource.selectedTraits},
    cancellation: scope,
    fetch: () => _fetchSelectedTraits(scope),
  );

  Future<List<ProfileTrait>> _fetchSelectedTraits(RequestCancellation s) =>
      _list('/api/users/me/traits', 'traits', ProfileTrait.fromJson, s);

  @override
  Future<List<ProfileQuestion>> questions(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.questions,
    policy: policy,
    tags: {DataResource.questions},
    cancellation: scope,
    fetch: () => _fetchQuestions(scope),
  );

  Future<List<ProfileQuestion>> _fetchQuestions(RequestCancellation s) =>
      _list('/api/profile-questions', 'questions', ProfileQuestion.fromJson, s);

  @override
  Future<List<ProfileAnswer>> answers(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.answers,
    policy: policy,
    tags: {DataResource.answers},
    cancellation: scope,
    fetch: () => _fetchAnswers(scope),
  );

  Future<List<ProfileAnswer>> _fetchAnswers(RequestCancellation s) => _list(
    '/api/users/me/profile-answers',
    'answers',
    ProfileAnswer.fromJson,
    s,
  );

  @override
  Future<void> saveProfile(ProfileDraft draft) async {
    if (draft.validate(DateTime.now()) != null) {
      throw const ApiFailure(ApiFailureKind.validation);
    }
    await _request('PATCH', '/api/users/me/profile', body: draft.toJson());
  }

  @override
  Future<void> savePreferences(Preferences p) async {
    if (p.validate() != null) throw const ApiFailure(ApiFailureKind.validation);
    await _request('PATCH', '/api/users/me/preferences', body: p.toJson());
  }

  @override
  Future<void> setTrait(String id, bool selected) async {
    serverId({'id': id}, 'id');
    await _request(
      selected ? 'POST' : 'DELETE',
      selected ? '/api/users/me/traits' : '/api/users/me/traits/$id',
      body: selected ? {'traitId': id} : null,
      status: 204,
    );
  }

  @override
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

  @override
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
    if (!validPhotoUrl(jsonString(j, 'photo'))) invalidResponse();
    Moderation.parse(
      jsonString(j, 'moderation_status'),
      j['moderation_reasons'],
    );
  }

  @override
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
