# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Stripe SDK - Keep all classes and suppress warnings
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Suppress specific missing class warnings that cause build failure
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# React Native Stripe SDK (if applicable)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# General Proguard settings
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Additional safety rules
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Suppress all warnings (use with caution)
-ignorewarnings
