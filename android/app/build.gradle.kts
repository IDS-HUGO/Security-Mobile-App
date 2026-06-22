plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.appmobile_security"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.appmobile_security"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage usa EncryptedSharedPreferences, que requiere
        // API 23+ para encriptar el token y las variables de tiempo de sesion.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Se firma con las llaves de depuración para que la práctica
            // (`flutter build apk --release`) funcione sin un keystore propio.
            signingConfig = signingConfigs.getByName("debug")

            // ============================================================
            //  OFUSCACIÓN / MINIMIZACIÓN CON R8  (práctica de ofuscación)
            // ============================================================
            // R8 se activa AUTOMÁTICAMENTE cuando la compilación usa la bandera
            // --obfuscate de Flutter: en ese caso Flutter pasa a Gradle la
            // propiedad `dart-obfuscation=true`, que aquí se lee para encender
            // también la minificación/ofuscación de la capa Java/Kotlin. Así se
            // generan DOS APK desde el mismo proyecto SIN editar este archivo:
            //
            //   • APK NORMAL (sin ofuscar):
            //       flutter build apk --release
            //
            //   • APK OFUSCADA (R8 + ProGuard + ofuscación del código Dart):
            //       flutter build apk --release --obfuscate \
            //         --split-debug-info=build/symbols
            //
            // R8 realiza tres tareas en una sola pasada:
            //   - shrinking     → elimina clases/métodos/recursos sin uso,
            //   - optimization  → simplifica y reescribe el bytecode,
            //   - obfuscation   → renombra clases, métodos y campos (a, b, c…).
            //
            // (También puede forzarse manualmente con -Pobfuscate=true.)
            fun flag(name: String) =
                (project.findProperty(name) as String?)?.toBoolean() ?: false
            val enableObfuscation = flag("dart-obfuscation") || flag("obfuscate")

            isMinifyEnabled = enableObfuscation      // activa R8 (shrink + ofuscación)
            isShrinkResources = enableObfuscation    // elimina recursos no usados

            proguardFiles(
                // Reglas por defecto de R8 con optimizaciones activadas.
                getDefaultProguardFile("proguard-android-optimize.txt"),
                // Reglas "keep" propias (Flutter, Firebase, secure storage…).
                "proguard-rules.pro",
            )
        }
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
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
