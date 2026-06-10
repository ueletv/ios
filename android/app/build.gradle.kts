plugins {
    id("com.android.application")
    // Built-in Kotlin (AGP 9+)；勿再应用 org.jetbrains.kotlin.android
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.video.videoweb_flutter"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.video.videoweb_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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

configurations.configureEach {
    resolutionStrategy {
        // url_launcher 6.3.x 默认拉取需 compileSdk 36 的 AndroidX，本机 SDK 为 35 时锁定兼容版本
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.core:core:1.15.0")
    }
}

dependencies {
    // 直播间 SVGA 礼物全屏动画（与原生 SVGAPlayer-Android 一致）
    implementation("com.github.yyued:SVGAPlayer-Android:2.6.1")
}
