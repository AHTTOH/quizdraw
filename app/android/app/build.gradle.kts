plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.quizdraw.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // 플러그인 호환성을 위해 최신 버전으로 업데이트

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 실제 배포용 Application ID
        applicationId = "com.quizdraw.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // TODO: 실제 키스토어 파일 경로로 변경
            storeFile = file("quizdraw-release-key.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_keystore_password"
            keyAlias = System.getenv("KEY_ALIAS") ?: "upload"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
        }
    }

    buildTypes {
        release {
            // 임시로 서명 비활성화 (키스토어 문제 해결 후 활성화)
            // signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false  // 임시로 비활성화
            isShrinkResources = false  // 리소스 축소도 비활성화
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
