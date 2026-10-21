import 'package:flutter/foundation.dart';

import '../../../core/l10n/api_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/read_snapshots.dart';
import 'plan_catalog.dart';

abstract interface class CatalogRepository {
  factory CatalogRepository(ApiClient api, {Listenable? languageChanges}) =
      ApiCatalogRepository;

  ApiLanguage get language;
  Listenable? get languageChanges;

  Future<PlanCatalog> load(
    RequestCancellation cancellation, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  void close();
}

final class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api, {this.languageChanges});
  @override
  final Listenable? languageChanges;
  @override
  ApiLanguage get language => _api.language;
  final ApiClient _api;
  final _reads = ReadSnapshots();

  @override
  Future<PlanCatalog> load(
    RequestCancellation cancellation, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: language.code,
    key: DataResource.plans,
    policy: policy,
    cancellation: cancellation,
    fetch: () async {
      final body = await _api.getJson('/api/plans', cancellation: cancellation);
      try {
        return PlanCatalog.fromJson(body);
      } on FormatException {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
    },
  );

  @override
  void close() {
    _reads.clear();
    _api.close();
  }
}
