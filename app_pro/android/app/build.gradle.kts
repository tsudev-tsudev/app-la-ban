import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tsudev.laban.pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // M2 (Q56): app "La bàn Pro" - listing Play riêng, cùng mã nguồn (packages/app_shell), KHÔNG phụ thuộc quảng cáo.
        applicationId = "com.tsudev.laban.pro"
        // minSdk 26 (Android 8.0) - QUYET_DINH Q50 (R3a MobSF): Android 7.x hết vá bảo mật -> MobSF High
        // "vulnerable unpatched Android version". Không hạ lại mà không ghi QUYET_DINH.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Ba flavor cài song song được trên một máy (QUYET_DINH Q20).
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "La bàn Pro DEV"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            manifestPlaceholders["appName"] = "La bàn Pro STG"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "La bàn Pro"
        }
    }

    // Nén thư viện native (giống app/). App Pro KHÔNG phát hành APK ngoài Play (M2 bước 2) - chỉ AAB.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            // --target-platform chỉ lọc libflutter/libapp; thư viện native của plugin (freeRASP libts.so ~13 MB nén mỗi ABI)
            // vẫn đủ 3 ABI. Flutter ghi đè ndk.abiFilters nên loại ABI thừa ở bước đóng gói.
            (project.findProperty("target-platform") as String?)?.let { tp ->
                val abi = mapOf("android-arm" to "armeabi-v7a", "android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
                val giu = tp.split(",").mapNotNull { abi[it.trim()] }.toSet()
                if (giu.isNotEmpty()) (abi.values - giu).forEach { excludes += "lib/$it/**" }
            }
        }
    }

    // Khoá upload (QUYET_DINH Q34) nằm NGOÀI repo: LA_BAN_KEY_PROPERTIES hoặc ~/.config/la-ban/android/key.properties.
    // Không có tệp (máy khác / CI) -> bản release ký debug, chỉ dùng thử cục bộ; script phát hành bắt buộc có khoá.
    val tepKhoa = file(System.getenv("LA_BAN_KEY_PROPERTIES") ?: "${System.getProperty("user.home")}/.config/la-ban/android/key.properties")
    val khoa = Properties().apply { if (tepKhoa.isFile) tepKhoa.inputStream().use { load(it) } }
    signingConfigs {
        if (khoa.getProperty("storeFile") != null) {
            create("upload") {
                storeFile = file(khoa.getProperty("storeFile"))
                storePassword = khoa.getProperty("storePassword")
                keyAlias = khoa.getProperty("keyAlias")
                keyPassword = khoa.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
            // SEC-APP APP-01 / APP-06: R8 (AGP 9 mặc định full mode) + thu gọn tài nguyên; release không debuggable.
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
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
