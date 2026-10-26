import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';

enum ConsentType {
  terms('terms_of_service_acceptance'),
  privacy('privacy_notice_acknowledgement'),
  sensitive('sensitive_data_consent'),
  location('location_consent');

  const ConsentType(this.wireName);
  final String wireName;
  bool get withdrawable => this == sensitive || this == location;
  static ConsentType parse(String value) => values.firstWhere(
    (type) => type.wireName == value,
    orElse: () => throw const ApiFailure(ApiFailureKind.invalidResponse),
  );
}

/// A document's calendar date carries no account timestamp or timezone.
DateTime? parseDocumentDate(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    invalidResponse();
  }
  final date = DateTime.tryParse(value);
  if (date == null || date.toIso8601String().substring(0, 10) != value) {
    invalidResponse();
  }
  return date;
}

class PublicConsent {
  const PublicConsent({
    required this.type,
    required this.granted,
    required this.documentVersion,
    required this.requiredVersion,
    required this.documentUrl,
    required this.updatedAt,
    this.documentLanguage = ApiLanguage.fr,
    this.acceptedDocumentLanguage,
    this.documentDate,
  });

  factory PublicConsent.fromJson(Object? value) {
    final json = jsonObject(value);
    final version = json['document_version'];
    final updated = json['updated_at'];
    if ((version != null && version is! String) ||
        (updated != null &&
            (updated is! String || DateTime.tryParse(updated) == null))) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return PublicConsent(
      type: ConsentType.parse(jsonString(json, 'consent_type')),
      granted: jsonField<bool>(json, 'granted'),
      documentVersion: version as String?,
      requiredVersion: jsonString(json, 'required_document_version'),
      documentUrl: jsonString(json, 'document_url'),
      updatedAt: updated as String?,
      documentDate: parseDocumentDate(json['document_date']),
      documentLanguage:
          ApiLanguage.tryParse(json['document_language']) ??
          (throw const ApiFailure(ApiFailureKind.invalidResponse)),
      acceptedDocumentLanguage: json['accepted_document_language'] == null
          ? null
          : ApiLanguage.tryParse(json['accepted_document_language']) ??
                (throw const ApiFailure(ApiFailureKind.invalidResponse)),
    );
  }
  final ConsentType type;
  final bool granted;
  final String? documentVersion;
  final String requiredVersion;
  final String documentUrl;
  final String? updatedAt;
  final DateTime? documentDate;
  final ApiLanguage documentLanguage;
  final ApiLanguage? acceptedDocumentLanguage;

  bool get current => granted && documentVersion == requiredVersion;
}

class ConsentState {
  ConsentState(
    List<PublicConsent> consents,
    this.onboardingComplete,
    List<ConsentType> requiredActions,
  ) : consents = List.unmodifiable(consents),
      requiredActions = List.unmodifiable(requiredActions);

  factory ConsentState.fromJson(Object? value) {
    final json = jsonObject(value);
    final consents = jsonField<List<dynamic>>(
      json,
      'consents',
    ).map(PublicConsent.fromJson).toList(growable: false);
    if (consents.length != 4 ||
        consents.map((c) => c.type).toSet().length != 4) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final actions = jsonField<List<dynamic>>(json, 'required_actions')
        .map((v) {
          if (v is! String) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          return ConsentType.parse(v);
        })
        .toList(growable: false);
    return ConsentState(
      List.unmodifiable(consents),
      jsonField<bool>(json, 'onboarding_complete'),
      List.unmodifiable(actions),
    );
  }
  final List<PublicConsent> consents;
  final bool onboardingComplete;
  final List<ConsentType> requiredActions;
}
