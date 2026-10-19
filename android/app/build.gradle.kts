plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Public client configuration only. Native resources let Firebase receive a
// cold-start message too. No service account or fallback project is bundled.
val histaePublicEnv = rootProject.file("../.env").takeIf { it.exists() }
    ?.readLines()?.mapNotNull { raw ->
        val line = raw.trim().removePrefix("\uFEFF")
        val at = line.indexOf('=')
        if (line.startsWith("#") || at < 1) null else
            line.substring(0, at).trim() to line.substring(at + 1).trim()
                .removeSurrounding("\"").removeSurrounding("'")
    }?.toMap().orEmpty()
val histaeAndroidPush = histaePublicEnv["PUSH_ENABLED"] == "true" &&
    listOf("FIREBASE_PROJECT_ID", "FIREBASE_MESSAGING_SENDER_ID", "FIREBASE_ANDROID_API_KEY", "FIREBASE_ANDROID_APP_ID")
        .all { !histaePublicEnv[it].isNullOrBlank() }
val histaeAdmobAppId = histaePublicEnv["ADMOB_ANDROID_APP_ID"].orEmpty()
require(histaeAdmobAppId.isEmpty() || Regex("^ca-app-pub-\\d{16}~\\d{10}$").matches(histaeAdmobAppId)) {
    "Invalid ADMOB_ANDROID_APP_ID in .env"
}

android {
    buildFeatures { resValues = true }
    namespace = "com.histae.histae_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.histae.histae_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "histae_admob_app_id", histaeAdmobAppId)
        if (histaeAndroidPush) {
            mapOf("google_app_id" to "FIREBASE_ANDROID_APP_ID", "google_api_key" to "FIREBASE_ANDROID_API_KEY",
                "gcm_defaultSenderId" to "FIREBASE_MESSAGING_SENDER_ID", "project_id" to "FIREBASE_PROJECT_ID")
                .forEach { (resource, key) -> resValue("string", resource, histaePublicEnv.getValue(key)) }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
