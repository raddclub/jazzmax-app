# JazzMAX ProGuard / R8 rules

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# media_kit (FFmpeg/libmpv native bindings)
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }

# Dio / OkHttp networking
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Flutter secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# device_info_plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Riverpod
-keep class dev.rvr.** { *; }

# Keep JazzMAX app models (prevent obfuscation of data classes)
-keep class com.jazzmax.app.** { *; }

# Google Play Core — referenced by Flutter's FlutterPlayStoreSplitApplication
# but not needed for sideloaded / direct APK distribution.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Generic Android rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-dontwarn sun.misc.**
