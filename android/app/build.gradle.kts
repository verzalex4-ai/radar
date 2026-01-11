plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rada_prueba"

    // Compatible con Android 8.0+ (API 26+)
    // Necesario para nearby_connections y permisos modernos
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.rada_prueba"

        // Android 8.0 Oreo como mínimo
        // nearby_connections requiere mínimo API 23, pero para mejor compatibilidad usamos 26
        minSdk = 26

        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ⚠️ IMPORTANTE: Para producción debes crear y usar tu propio keystore
            // Por ahora usa el keystore de debug para testing
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // No necesitas agregar dependencias manualmente
    // Flutter las maneja automáticamente desde pubspec.yaml
}