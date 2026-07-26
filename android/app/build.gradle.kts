import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")  // ملف منفصل، وليس local.properties
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.friendschalets.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.friendschalets.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("RELEASE_KEY_ALIAS")
                ?: throw GradleException("RELEASE_KEY_ALIAS غير موجود في key.properties")
            keyPassword = keystoreProperties.getProperty("RELEASE_KEY_PASSWORD")
                ?: throw GradleException("RELEASE_KEY_PASSWORD غير موجود في key.properties")
            storeFile = keystoreProperties.getProperty("RELEASE_STORE_FILE")?.let { file(it) }
                ?: throw GradleException("RELEASE_STORE_FILE غير موجود في key.properties")
            storePassword = keystoreProperties.getProperty("RELEASE_STORE_PASSWORD")
                ?: throw GradleException("RELEASE_STORE_PASSWORD غير موجود في key.properties")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}