import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release-signing credentials from android/key.properties if present.
// This file holds the keystore path/passwords and must NEVER be committed.
// When absent (e.g. on a fresh clone), release builds fall back to the debug
// key so `flutter run --release` still works locally.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.localvyapari.local_vyapari_user"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.localvyapari.local_vyapari_user"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No release keystore yet — fall back to debug so local release
                // builds work. DO NOT publish a debug-signed build to the Play Store.
                signingConfigs.getByName("debug")
            }
            // Shrink and obfuscate the release build (R8). Reduces APK size and
            // makes reverse-engineering harder.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

tasks.register("copyLogos") {
    doLast {
        val srcFile = file("C:/Users/adith/.gemini/antigravity/brain/0a7d04d1-6af7-441a-99b1-da540a0d8c6c/media__1780986388840.png")
        if (srcFile.exists()) {
            copy {
                from(srcFile)
                into("src/main/res/drawable")
                rename { "ic_notification.png" }
            }
            copy {
                from(srcFile)
                into("../../assets/images")
                rename { "logo.png" }
            }
            copy {
                from(srcFile)
                into("../../assets/images")
                rename { "logo_white.png" }
            }
            println("[Gradle] Successfully copied new logos from temporary brain directory.")
        } else {
            println("[Gradle] Source logo file not found or already deleted; skipping copy task.")
        }
    }
}

tasks.named("preBuild") {
    dependsOn("copyLogos")
}

