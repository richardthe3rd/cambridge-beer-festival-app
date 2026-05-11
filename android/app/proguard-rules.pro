# Flutter wrapper classes (wildcard covers all io.flutter.** subpackages)
-keep class io.flutter.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Preserve source file names and line numbers so crash stack traces are actionable
# (required by Firebase Crashlytics and Play Console for meaningful deobfuscation)
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Firebase SDKs bundle their own consumer ProGuard rules, but suppress missing-class
# warnings for GMS classes that may be referenced but not included in all variants.
-dontwarn com.google.android.gms.**

# Lifecycle interfaces are referenced by Firebase but resolved at runtime via the AAR;
# suppress only the specific optional-observer interface, not all of androidx.lifecycle.
-dontwarn androidx.lifecycle.DefaultLifecycleObserver

# Suppress warnings about missing optional TLS provider classes (used by OkHttp)
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Flutter references Play Core split-install classes for deferred component support.
# This app does not use dynamic feature modules, so these classes are absent at
# compile time.  Suppress the missing-class errors R8 raises for them.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
