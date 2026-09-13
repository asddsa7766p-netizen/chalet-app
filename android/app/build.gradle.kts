import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()

// Robustly resolve key.properties. Gradle may run with different JVM/env
// settings, so check several reliable locations in this order:
// 1) %USERPROFILE%/.android/key.properties (Windows)
// 2) $user.home/.android/key.properties (JVM user.home)
// 3) project root android/key.properties (tracked fallback)
val envUserProfile: String? = System.getenv("USERPROFILE")
val envHome: String? = System.getenv("HOME")
val jvmUserHome: String? = System.getProperty("user.home")

fun propFileAt(dir: String?): File? {
    if (dir == null) return null
    val f = File(dir, ".android${File.separator}key.properties")
    return if (f.exists()) f else null
}

val candidateFiles = listOfNotNull(
    propFileAt(envUserProfile),
    propFileAt(jvmUserHome),
    propFileAt(envHome),
    rootProject.file("key.properties")
)

val keystorePropertiesFile: File? =
    candidateFiles.firstOrNull { it.exists() }

if (keystorePropertiesFile != null) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }

    // Clean up keys/values
    fun String.removeBom() =
        this.replace("\uFEFF", "").trim()

    val cleaned = Properties()

    for (name in keystoreProperties.stringPropertyNames()) {
        val cleanKey = name
            .removeBom()
            .replace(Regex("^[^A-Za-z0-9_]+"), "")

        val rawVal =
            keystoreProperties.getProperty(name) ?: ""

        val cleanVal =
            rawVal.removeBom()

        cleaned.setProperty(cleanKey, cleanVal)
    }

    keystoreProperties.clear()
    keystoreProperties.putAll(cleaned)

    // Log only non-secret information
    println(
        "Loaded signing properties from: ${keystorePropertiesFile.absolutePath}"
    )

    println(
        "Signing property keys: ${
            keystoreProperties.stringPropertyNames()
                .joinToString(",")
        }"
    )
}

android {
    namespace = "com.makan.app"
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
        applicationId = "com.makan.app"
        minSdk = flutter.minSdkVersion
        compileSdk = 36
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isEmpty) {
                throw GradleException(
                    "لم يتم العثور على key.properties في الـ user home أو في جذر المشروع"
                )
            }

            keyAlias =
                keystoreProperties.getProperty("RELEASE_KEY_ALIAS")
                    ?: throw GradleException(
                        "RELEASE_KEY_ALIAS غير موجود في key.properties"
                    )

            keyPassword =
                keystoreProperties.getProperty("RELEASE_KEY_PASSWORD")
                    ?: throw GradleException(
                        "RELEASE_KEY_PASSWORD غير موجود في key.properties"
                    )

            val storeFileProperty =
                keystoreProperties.getProperty("RELEASE_STORE_FILE")
                    ?: throw GradleException(
                        "RELEASE_STORE_FILE غير موجود في key.properties"
                    )

            val loadedFromDir =
                keystorePropertiesFile?.parentFile

            storeFile = when {
                File(storeFileProperty).isAbsolute ->
                    File(storeFileProperty)

                loadedFromDir != null ->
                    File(loadedFromDir, storeFileProperty)

                else ->
                    file(storeFileProperty)
            }

            storePassword =
                keystoreProperties.getProperty("RELEASE_STORE_PASSWORD")
                    ?: throw GradleException(
                        "RELEASE_STORE_PASSWORD غير موجود في key.properties"
                    )
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}