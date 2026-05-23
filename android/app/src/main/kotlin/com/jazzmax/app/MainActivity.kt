package com.jazzmax.app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        const val PIP_CHANNEL    = "com.jazzmax.app/pip"
        const val SECURE_CHANNEL = "com.jazzmax.app/secure"
        const val ROOT_CHANNEL   = "com.jazzmax.app/root"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Picture-in-Picture ───────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enter" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(16, 9))
                                    .build()
                                enterPictureInPictureMode(params)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "isSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── FLAG_SECURE — blocks screenshots & screen recording ──────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Root / tamper / emulator detection ──────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROOT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRooted"   -> result.success(isDeviceRooted())
                    "isEmulator" -> result.success(isEmulator())
                    else         -> result.notImplemented()
                }
            }
    }

    private fun isDeviceRooted(): Boolean {
        val suPaths = arrayOf(
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su",
            "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su",
            "/su/bin/su", "/system/app/SuperSU.apk", "/system/app/Kinguser.apk"
        )
        for (path in suPaths) { if (File(path).exists()) return true }
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true
        return false
    }

    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
        Build.FINGERPRINT.startsWith("unknown") ||
        Build.MODEL.contains("google_sdk") ||
        Build.MODEL.contains("Emulator") ||
        Build.MODEL.contains("Android SDK") ||
        Build.MANUFACTURER.contains("Genymotion") ||
        Build.BRAND.startsWith("generic") ||
        Build.DEVICE.startsWith("generic") ||
        "google_sdk" == Build.PRODUCT
}
