import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';

/// Account preference; an explicit request header may still override it.
class LanguageRepository {
  LanguageRepository(this.session);
  final AuthenticatedSession session;

  Future<ApiLanguage> read(RequestCancellation cancellation) async => _parse(
    await session.request(
      'GET',
      '/api/users/me/language',
      expectedStatus: 200,
      replayAfterRefresh: true,
      cancellation: cancellation,
    ),
  );

  Future<void> write(
    ApiLanguage language,
    RequestCancellation cancellation,
  ) async {
    final confirmed = _parse(
      await session.request(
        'PATCH',
        '/api/users/me/language',
        body: {'language': language.code},
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: cancellation,
      ),
    );
    if (confirmed != language) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
  }

  ApiLanguage _parse(Object? value) =>
      ApiLanguage.tryParse(jsonObject(value)['language']) ??
      (throw const ApiFailure(ApiFailureKind.invalidResponse));
}
