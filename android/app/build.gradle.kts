plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.etracker_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.etracker_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources.excludes.add("META-INF/{AL2.0,LGPL2.1}")
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")

    // Google Play Services location (FusedLocationProviderClient)
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // OkHttp for HTTP requests from LocationService + RescueWorker
    implementation("com.squareup.okhttp3:okhttp:4.10.3")

    // AndroidX core
    implementation("androidx.core:core-ktx:1.12.0")

    // Coroutines (used by WorkManager ktx extension)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // WorkManager — the ONLY mechanism that reliably survives OEM aggressive kill.
    // Backed by JobScheduler; the OS guarantees it runs even after app process kill.
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
