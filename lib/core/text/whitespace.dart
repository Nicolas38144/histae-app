// Same outer whitespace set as ECMAScript/Rust, not Dart's additional NEL.

final _edgeSpace = RegExp(
  r'^[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+|[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+$',
);

String trimOuterWhitespace(String value) => value.replaceAll(_edgeSpace, '');
