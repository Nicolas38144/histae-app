# Source access and licensing

Reviewed on 2026-10-23. This guide describes repository licensing, not the user terms of
the official Histae application or a certification of legal compliance.

## Original Histae materials

The seven repositories (app, Rust API, website, dashboard, legacy API, scripts and reverse
proxy) use matching proprietary [source-access terms](../LICENSE.md). The Rust API's two
nested npm tools carry the same terms. Inspection, local compilation and isolated execution
strictly for security auditing are permitted. Reuse in another project, including personal,
educational and non-commercial projects, redistribution and operation of another service
require prior written permission. Temporary audit modifications do not create a general
derivative-work permission. External contributions are not accepted.

Public source access is not an open-source license. Mandatory legal rights remain reserved.
On GitHub, public repositories can still be viewed and forked under the platform terms;
the proprietary terms cannot remove that platform permission. They do not grant a general
right to exploit or reuse the code. Previously granted rights cannot simply be revoked by
replacing a license file; historical grants and contributor ownership were not audited.

References: [GitHub repository licensing](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository),
[GitHub terms](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users).

## Third-party review

Each repository has THIRD_PARTY_NOTICES.md and a dated THIRD_PARTY_LICENSES.json inventory.
The inventories contain declared licenses of package versions resolved at review time,
including development and optional packages. Counts overlap across projects and do not
represent the number of packages shipped in a release.

| Repository | Recorded package entries |
| --- | ---: |
| App | 135 Dart packages, plus separately documented fonts and SDKs |
| Rust API | 366 crates, 99 npm entries across two tools, 4 direct Python requirements |
| Website | 474 npm entries |
| Dashboard | 560 npm entries |
| Legacy API | 727 npm entries |
| Scripts and reverse proxy | Infrastructure review; no package tree inventoried |

The [app review](../THIRD_PARTY_NOTICES.md) preserves the three font OFL texts and identifies
MPL desktop packages. The Rust and legacy API reports identify MPL WebAuthn code and LGPL
image codecs. Redis 7.4, Grafana and PostGIS have their own distinct infrastructure licenses.
None of these components can be relicensed under Histae's restrictions. Copyleft terms do
not automatically make all original Histae code open source; obligations depend on the
specific licenses, modifications, combination and distribution.

## Metadata and release follow-up

Private npm packages reference their custom LICENSE.md; Cargo uses license-file and
publish = false; the Flutter app retains publish_to: none. These settings describe the
license and discourage accidental registry publication; they are not access controls.

Before distributing a release, check the actual shipped native SDKs, WebAssembly/binary
codecs, generated browser bundles, containers and required attribution/source bundles.
Python transitive requirements are not locked in the current moderation service. ONNX
model weights require their own provenance and license review. Complete container/OS and
mobile native dependency inventories remain outside this package-metadata review.

No production service, payment or advertising flow was exercised. No API tests were run.
The work checks license consistency and records known obligations; it does not substitute
for legal review of enforceability, historic licensing or release compliance.
