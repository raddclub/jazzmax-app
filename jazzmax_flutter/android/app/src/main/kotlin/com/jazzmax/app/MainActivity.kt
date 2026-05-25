package com.jazzmax.app

import android.app.PictureInPictureParams
import android.media.MediaScannerConnection
import android.content.Intent
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Cast SDK imports
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val PIP_CHANNEL   = "com.jazzmax.app/pip"
    private val MEDIA_CHANNEL = "com.jazzmax.app/media"
    private val CAST_CHANNEL = "com.jazzmax.app/cast"

    private var castContext: CastContext? = null
    private var castSession: CastSession? = null
    private var castSessionListener: SessionManagerListener<CastSession>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── PiP Channel ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPiP" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }


        // ── Media Scanner Channel ────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val scanPath = call.argument<String>("path")
                        if (scanPath != null) {
                            MediaScannerConnection.scanFile(this, arrayOf(scanPath), null, null)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // ── Cast Channel ─────────────────────────────────────────────────
        try {
            castContext = CastContext.getSharedInstance(this)
        } catch (e: Exception) {
            // Cast SDK unavailable on this device — silently ignore
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "discoverDevices" -> {
                        try {
                            val devices = mutableListOf<Map<String, String>>()
                            // Return current cast device if connected
                            val sess = castContext?.sessionManager?.currentCastSession
                            if (sess != null && sess.isConnected) {
                                val ri = sess.castDevice
                                if (ri != null) devices.add(mapOf(
                                    "id" to (ri.deviceId ?: ""),
                                    "name" to (ri.friendlyName ?: "Chromecast"),
                                    "model" to (ri.modelName ?: "")
                                ))
                            }
                            result.success(devices)
                        } catch (e: Exception) { result.success(listOf<Map<String,String>>()) }
                    }

                    "castVideo" -> {
                        try {
                            val url       = call.argument<String>("url") ?: ""
                            val title     = call.argument<String>("title") ?: ""
                            val posterUrl = call.argument<String>("posterUrl") ?: ""
                            val posMs     = call.argument<Int>("positionMs") ?: 0

                            val sess = castContext?.sessionManager?.currentCastSession
                            if (sess == null || !sess.isConnected) {
                                result.success(false); return@setMethodCallHandler
                            }
                            val meta = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
                            meta.putString(MediaMetadata.KEY_TITLE, title)

                            val mediaInfo = MediaInfo.Builder(url)
                                .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                                .setContentType("video/mp4")
                                .setMetadata(meta)
                                .build()

                            val loadRequest = MediaLoadRequestData.Builder()
                                .setMediaInfo(mediaInfo)
                                .setCurrentTime(posMs.toLong())
                                .setAutoplay(true)
                                .build()

                            sess.remoteMediaClient?.load(loadRequest)
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }

                    "pause"  -> { castSession?.remoteMediaClient?.pause();  result.success(null) }
                    "resume" -> { castSession?.remoteMediaClient?.play();   result.success(null) }
                    "stop"   -> { castSession?.remoteMediaClient?.stop();   result.success(null) }
                    "seek"   -> {
                        val ms = call.argument<Int>("positionMs") ?: 0
                        castSession?.remoteMediaClient?.seek(ms.toLong())
                        result.success(null)
                    }
                    "isConnected" -> {
                        val connected = castContext?.sessionManager?.currentCastSession?.isConnected == true
                        result.success(connected)
                    }
                    "disconnect" -> {
                        castContext?.sessionManager?.endCurrentSession(true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
