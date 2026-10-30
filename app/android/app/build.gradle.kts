import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tsudev.laban"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tsudev.laban"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
            manifestPlaceholders["appName"] = "La bàn DEV"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            manifestPlaceholders["appName"] = "La bàn STG"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "La bàn"
        }
    }

    // Nén thư viện native trong APK: tệp tải trực tiếp (Q34) nhỏ đi gần một nửa; bản Play (AAB) do Play tự tối ưu.
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
