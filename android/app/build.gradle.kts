plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "work.michaelnet.enfocate"
    compileSdk = 36

    defaultConfig {
        applicationId = "work.michaelnet.enfocate"
        minSdk = 26
        // Google Play exige apuntar a Android 16 desde el 31 de agosto de 2026.
        targetSdk = 36
        // La compilación de GitHub pone su número, para que cada versión sea mayor que la anterior.
        versionCode = System.getenv("VERSION_CODE")?.toIntOrNull() ?: 1
        versionName = "0.1.0"
    }

    // La firma de las versiones públicas viene de secretos de GitHub, nunca del repositorio.
    // Sin ellos, la versión release queda sin firmar.
    val almacenFirma = System.getenv("ANDROID_KEYSTORE")
    signingConfigs {
        if (almacenFirma != null) {
            create("publica") {
                storeFile = file(almacenFirma)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            if (almacenFirma != null) signingConfig = signingConfigs.getByName("publica")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

dependencies {
    val bom = platform("androidx.compose:compose-bom:2025.05.01")
    implementation(bom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    testImplementation("junit:junit:4.13.2")
}
