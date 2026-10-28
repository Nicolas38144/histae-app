# Android release signing

[Documentation](../README.md#documentation)

Release builds use a private upload key. Google Play App Signing uses its separate app signing
key for installations delivered through Google Play. Debug builds retain their development key.
See the [Flutter signing guide](https://docs.flutter.dev/deployment/android#sign-the-app) and
[Android signing guide](https://developer.android.com/studio/publish/app-signing).

## Local configuration and recovery

`android/key.properties` supplies `storeFile`, `storeType`, `storePassword`, `keyAlias` and
`keyPassword`. The keystore path is absolute, or relative to `android/`; use forward slashes in
Windows properties paths. This file is private and ignored by source tracking. Never put these
credentials in the root `.env`, which is bundled in the app.

The upload key created for this workstation is stored outside the repository in
`%USERPROFILE%/.android/histae-upload/upload-keystore.jks`, with alias `upload`. Its random
password and signing configuration have a recovery copy in the same private directory as
`key.properties`. The directory also contains the public `upload_certificate.pem` and recovery
instructions. Private files are restricted to the current Windows user and SYSTEM.

Back up this directory to secure storage outside this computer. Keep the keystore and password
together in that protected backup; neither belongs in a commit, build artifact or shared log.
To restore on another machine, copy the private `key.properties` to `android/key.properties`
and update only `storeFile` to the restored keystore's absolute location. Keep using the same
key for later uploads; do not regenerate it for every release.

Release builds stop with an error if signing configuration or the keystore is missing. They
never fall back to the debug key. Debug builds remain available without release credentials.

## Build and verify

From the app root:

```bash
flutter build appbundle --release
```

The generated bundle is `build/app/outputs/bundle/release/app-release.aab`. Upload the `.aab`
to the intended Play Console testing track. Building does not upload or publish anything.
For later updates, increase the build number in `pubspec.yaml` or use `--build-number`.

With the JDK tools on PATH:

```bash
jarsigner "-J-Duser.language=en" -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
keytool "-J-Duser.language=en" -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
keytool "-J-Duser.language=en" -printcert -file <private-signing-directory>/upload_certificate.pem
```

The bundle must verify and its signer SHA-256 must match the public upload certificate. An
upload certificate is self-signed; a warning about its trust chain or the lack of a timestamp
is expected when verifying it against the JDK's public CA store. Signature verification does
not replace installation, startup and purchase checks through Google Play testing.
The language option keeps JDK certificate diagnostics readable on French Windows installations.
Some JDK versions also report `JarInputStream` layout warnings when the bundle's signing
manifest follows the payload entries. This release was additionally checked by fully reading
every payload through the verifying `JarFile` API and requiring its signer to match the upload
certificate; every payload passed. Do not dismiss unsigned-entry or digest-verification errors.

After enrolling in Play App Signing, use the Play **app signing certificate** fingerprints when
configuring providers that identify apps installed from Google Play. The upload certificate
identifies uploads; it is not necessarily the certificate used on users' devices.
