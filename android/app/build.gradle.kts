import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Podpisovací kľúč pre vydanie.
//
// Lokálne sa číta z android/key.properties (ten súbor ani .jks do repozitára
// nepatria – pozri .gitignore). V GitHub Actions sa to isté berie z premenných
// prostredia. Keď nie je ani jedno, release sa podpíše debug kľúčom – apka sa
// nainštaluje, ale nedá sa ňou aktualizovať tá vydaná.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(property: String, variable: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(variable)

val keystorePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

if (keystorePath == null) {
    logger.warn(
        "Chýba podpisovací kľúč (android/key.properties ani premenné prostredia) – " +
            "release APK sa podpíše debug kľúčom a nedá sa ním aktualizovať vydaná apka.",
    )
}

android {
    namespace = "com.theemis.recepty"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identita apky v telefóne. Po vydaní sa už nemení – iné ID je pre
        // Android iná aplikácia a nedá sa ňou aktualizovať tá nainštalovaná.
        applicationId = "com.theemis.recepty"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Verzia sa berie z pubspec.yaml (riadok version:).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
