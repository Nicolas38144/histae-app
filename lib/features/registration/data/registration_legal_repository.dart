import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../consents/domain/consent_state.dart';

class RegistrationLegalRepository {
  const RegistrationLegalRepository(this.session);
  final AuthenticatedSession session;

  Future<List<PublicConsent>> load(RequestCancellation cancellation) async {
    final json = jsonObject(
      await session.publicJson(
        '/api/legal/documents',
        cancellation: cancellation,
      ),
    );
    final documents = jsonField<List<dynamic>>(json, 'documents')
        .map((value) {
          final document = jsonObject(value);
          final uri = Uri.tryParse(jsonString(document, 'document_url'));
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          final language = ApiLanguage.tryParse(document['document_language']);
          if (language == null) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          return PublicConsent(
            type: ConsentType.parse(jsonString(document, 'consent_type')),
            granted: false,
            documentVersion: null,
            requiredVersion: jsonString(document, 'required_document_version'),
            documentUrl: uri.toString(),
            updatedAt: null,
            documentDate: parseDocumentDate(document['document_date']),
            documentLanguage: language,
          );
        })
        .toList(growable: false);
    if (documents.length != ConsentType.values.length ||
        documents.map((document) => document.type).toSet().length !=
            ConsentType.values.length) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return List.unmodifiable(documents);
  }
}
