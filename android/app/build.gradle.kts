import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tech.nextgenz.gnplay.creator"
    // flutter_plugin_android_lifecycle (dépendance transitive de file_picker)
    // exige compileSdk >= 36 ; le compileSdkVersion embarqué par ce SDK
    // Flutter est encore à 34.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "tech.nextgenz.gnplay.creator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signature de publication : android/key.properties (non versionné)
    // contenant storeFile, storePassword, keyAlias, keyPassword. Sans ce
    // fichier, le build release est signé avec la clé de debug (installable
    // en local, refusé par le Play Store).
    val keystoreFile = rootProject.file("key.properties")
    val keystore = Properties().apply {
        if (keystoreFile.exists()) keystoreFile.inputStream().use { load(it) }
    }

    signingConfigs {
        if (keystoreFile.exists()) {
            create("release") {
                storeFile = file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
