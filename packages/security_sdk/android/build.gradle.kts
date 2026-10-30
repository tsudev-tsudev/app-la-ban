group = "com.tsudev.laban.security"
version = "1.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.tsudev.laban.security"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=none")
            }
        }
    }

    // Kiểm tra môi trường bằng C++ (S4, Spec §7.3a) - mã ở native/android/cpp (QUYET_DINH Q32).
    ndkVersion = "28.2.13676358"
    externalNativeBuild {
        cmake {
            path = file("../../../native/android/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Play Integrity Standard API (QUYET_DINH Q7, SEC-ID ID-03). Cần Google Play Store trên máy; không có -> app gửi
// token null, server xếp mức 'unverified'.
dependencies {
    implementation("com.google.android.play:integrity:1.6.0")
}
