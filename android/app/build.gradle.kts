// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sponsorenlauf_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Basis-ID (nur Fallback; Flavors setzen die finale App-ID)
        applicationId = "com.example.sponsorenlauf_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Für jetzt Debug-Signatur, damit release-builds starten.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // >>> Flavors
    // Wichtig: Kotlin-DSL – saubere, gerade Anführungszeichen verwenden.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            // exakt die ID, die in Firebase (Android Dev App) registriert ist:
            applicationId = "ch.evpwetzikon.sponsorenlauf.dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Sponsorenlauf DEV")
        }
        create("prod") {
            dimension = "env"
            // zukünftige Prod-ID (falls du Android-Prod später nutzen willst)
            applicationId = "ch.evpwetzikon.sponsorenlauf"
            resValue("string", "app_name", "Sponsorenlauf")
        }
    }
}

flutter {
    source = "../.."
}
