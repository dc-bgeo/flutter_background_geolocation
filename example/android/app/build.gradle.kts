plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// bgeo_background_geolocation's android/build.gradle declares a local-maven repo
// (android/libs) for the closed-source bgeo-android AAR, but Gradle repository
// declarations are per-project: this app module also needs it to resolve that
// AAR as a *transitive* dependency (Gradle resolves a project's configuration
// using that project's own declared repositories, not a dependency project's).
repositories {
    maven { url = uri("${rootProject.projectDir}/../../android/libs") }
}

android {
    namespace = "com.bgeo.example.flutter"
    compileSdk = flutter.compileSdkVersion
    // The plugin ships no native/C++ code of its own, so the NDK is never used
    // for compilation — AGP only validates its presence. Pinned to a widely
    // available release so a partial/corrupted newer NDK download can't fail
    // the build for nothing.
    ndkVersion = "27.1.12297006"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bgeo.example.flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
