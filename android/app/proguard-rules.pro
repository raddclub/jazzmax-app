# ── JazzMAX ProGuard / R8 Rules ─────────────────────────────────────────────
# Release build: minifyEnabled=true, shrinkResources=true, obfuscation ON

# Flutter core — must not be renamed
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# media_kit / libmpv native bindings
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class kotlin.Lazy { *; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# Networking — Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Flutter plugins
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.github.ponnamkarthik.** { *; }

# JazzMAX app — keep main activity (Kotlin reflection)
-keep class com.jazzmax.app.MainActivity { *; }
-keep class com.jazzmax.app.** { *; }

# Google Play Core — unused but referenced by Flutter
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Attributes
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
-keep public class * extends java.lang.Exception

# Suppress misc warnings
-dontwarn sun.misc.**
-dontwarn java.lang.instrument.**
-dontwarn javax.annotation.**

# Aggressive obfuscation — repackage all non-kept classes into jmx namespace
-repackageclasses 'jmx'
-allowaccessmodification
-optimizationpasses 5

# Strip debug logs in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}
