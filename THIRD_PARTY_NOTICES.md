# Third-party licensing review

Reviewed on 2026-10-23.

[Histae's proprietary source-access terms](LICENSE.md) apply only to original Histae
materials. Dependencies, SDKs, fonts, container images and other third-party materials
retain their own licenses and rights, including reuse rights those licenses grant.

## Fonts and SDKs

The bundled Inter and Source Serif 4 fonts retain SIL Open Font License
1.1. Their original texts are preserved at:

- [Inter](assets/fonts/inter/OFL.txt)
- [Source Serif 4](assets/fonts/source_serif_4/OFL.txt)

DM Serif Display is no longer bundled. Its [original license](assets/fonts/dm_serif_display/OFL.txt)
is retained as a historical notice. The dated package inventory below also retains Cupertino Icons,
which was subsequently removed from the app's dependencies.

Flutter and its SDK packages retain the Flutter BSD license. Flutter's generated license
data and the existing font-license registration must be kept in release builds.
The resolved desktop packages `dbus` 0.7.15, `geoclue` 0.1.1 and `gsettings` 0.2.8 declare
MPL-2.0. Their presence in resolution does not prove they ship in Android or iOS binaries.
MPL file-level obligations must be retained where applicable.

This review does not resolve every native SDK/framework, CocoaPods, Gradle artifact,
advertising/service agreement or platform-specific binary. Verify those against each
actual release. Fonts and platform SDKs are not included in the package count below.

References: [OFL FAQ](https://openfontlicense.org/ofl-faq/),
[MPL FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/).

## Recorded package metadata

Native update integration added on 2026-10-30: `com.google.android.play:app-update:2.1.0`.
Its Maven POM declares the [Play Core SDK Terms of Service](https://developer.android.com/guide/playcore/license).
This SDK and its native dependencies retain their upstream terms; Histae's proprietary source
restrictions do not replace them. This addition does not change the dated Dart inventory below.

135 package-version entries are recorded in [THIRD_PARTY_LICENSES.json](THIRD_PARTY_LICENSES.json). These counts include build/test and optional packages and may repeat a package across nested tools. They do not describe the contents of a production artifact.

| Declared license expression | Entries |
| --- | ---: |
| `Apache-2.0` | 8 |
| `BSD-3-Clause` | 106 |
| `MIT` | 18 |
| `MPL-2.0` | 3 |

## Release responsibilities and limits

This review records declared licenses, not a complete attribution or license-text bundle.
Keep upstream copyright statements, LICENSE/NOTICE files and required attribution with
distributed components. Meet applicable source-availability and other copyleft requirements;
do not strip existing generated license information or third-party notices from bundles.
An `AND` expression requires satisfying both licenses; an `OR` expression allows a choice
subject to its terms. Unusual or custom expressions need the corresponding upstream text.

Before a release, review the actual dependency versions and shipped platform artifacts,
collect their full required texts and document any modifications. Base-image packages,
external service contracts, model weights and unpinned Python transitive packages have not
received a complete artifact-level review. No compatibility, ownership or legal-compliance
certification is asserted. This report does not revoke any earlier valid license grant.
