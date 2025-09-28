pluginManagement {
    // 1. Calculate the flutterSdkPath safely using the settings.rootDir context.
    // The 'run' block is executed once, and its result is assigned to flutterSdkPath.
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        
        // Safely resolve the local.properties file relative to the root directory
        // Use settings.rootDir to get the path to the main flutter project folder
        settings.rootDir.resolve("local.properties").inputStream().use { properties.load(it) } 
        
        val sdkPath = properties.getProperty("flutter.sdk")
        require(sdkPath != null) { "flutter.sdk not set in local.properties" }
        sdkPath
    } // <-- REMOVED THE TRAILING '()' HERE

    // 2. Include the Flutter Gradle toolchain build
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Configures repositories for *all* project dependencies, 
// ensuring plugins can find their required libraries (like com.android.library).
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

// Declares which plugins are available for projects to use.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"     // Flutter loader must be version 1.0.0
    id("com.android.application") version "8.13.0" apply false  // Application plugin (used by :app)
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false // Kotlin plugin
    id("com.android.library") version "8.13.0" apply false      // Library plugin (used by all plugins)
}

// Declares the sub-projects/modules in this build.
include(":app")
rootProject.name = "quickfix"