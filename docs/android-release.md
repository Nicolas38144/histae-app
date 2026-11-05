# Android release signing

[Documentation](../README.md#documentation)

Release uploads use a private upload key. Google Play App Signing uses a separate app-signing
key for delivered installations; debug builds use their development key. See
[Android signing](https://developer.android.com/studio/publish/app-signing).

## Configuration and recovery

Private `android/key.properties` supplies `storeFile`, `storeType`, `storePassword`, `keyAlias`
and `keyPassword`. Paths are absolute or relative to `android/`; use forward slashes on Windows.
Never put signing credentials in the bundled `.env`. Missing configuration fails release builds
without falling back to debug signing.

This workstation's key is `%USERPROFILE%/.android/histae-upload/upload-keystore.jks`, alias
`upload`. The same private directory contains recovery instructions/configuration, password and
public `upload_certificate.pem`; access is restricted to the Windows user and SYSTEM.

Back up that directory securely off-machine. To restore, copy its private `key.properties` to
`android/key.properties` and update `storeFile` to the restored key. Reuse the key for updates;
never commit it or include passwords in shared logs/artifacts.

## Build and verify

Increase the build number in `pubspec.yaml` or pass `--build-number`, then run:

```bash
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to the intended Play testing track.
The build command does not publish. With JDK tools on PATH:

```bash
jarsigner "-J-Duser.language=en" -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
keytool "-J-Duser.language=en" -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
keytool "-J-Duser.language=en" -printcert -file <private-signing-directory>/upload_certificate.pem
```

Verify the bundle signature and matching upload-certificate SHA-256. Self-signed trust-chain or
missing-timestamp warnings are expected; unsigned entries/digest failures are not. Then validate
installation, startup, upgrades and purchases through Play testing.

For providers identifying Play-installed apps, use the Play **app-signing** certificate fingerprint,
which can differ from the upload certificate. See [device checks](development.md#builds-and-device-checks).
