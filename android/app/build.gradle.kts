plugins {
    id("com.android.application")
    id("kotlin-android")
    // FlutterFire configuration plugin
    id("com.google.gms.google-services")
    // Flutter Gradle Plugin must be last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sliceit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.sliceit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Use debug signing for now — replace later with your own key
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Required for Firebase and multiDex
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("com.squareup.okhttp3:okhttp:4.12.0")
        force("com.squareup.okio:okio:3.6.0")
    }
}
