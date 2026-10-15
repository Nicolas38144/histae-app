import 'dart:convert';
import 'dart:io';

// Test-only data following src/catalog/domain.rs, with illustrative prices.
String catalogFixture() => File('test/fixtures/plans.json').readAsStringSync();
Map<String, dynamic> catalogJson() =>
    jsonDecode(catalogFixture()) as Map<String, dynamic>;
