pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val sdkPath = properties.getProperty("flutter.sdk")
        require(sdkPath != null) { "flutter.sdk not set in local.properties" }
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"    // do NOT use apply false
    id("com.android.application") version "8.13.0" apply false  // keep actual AGP version
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.android.library") version "8.13.0" apply false
}

include(":app")