# Flutter wrapper classes (wildcard covers all io.flutter.** subpackages)
-keep class io.flutter.** { *; }

# Preserve Flutter plugin registrant (auto-generated)
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep annotations used by Flutter plugins
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Firebase SDKs bundle their own consumer ProGuard rules, but suppress missing-class
# warnings for GMS classes that may be referenced but not included in all variants.
-dontwarn com.google.android.gms.**

# Suppress warnings about missing optional classes
-dontwarn androidx.lifecycle.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
