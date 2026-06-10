package com.video.videoweb_flutter

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(SVGA_VIEW_TYPE, LiveGiftSvgaViewFactory())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val url = call.argument<String>("url").orEmpty()
                    val duration = call.argument<Int>("duration") ?: 4
                    LiveGiftSvgaHolder.play(url, duration)
                    result.success(null)
                }
                "clear" -> {
                    LiveGiftSvgaHolder.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CONTROLS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBrightness" -> {
                        val lp = window.attributes
                        val brightness = lp.screenBrightness
                        val normalized = if (brightness < 0f) 0.5 else brightness.toDouble()
                        result.success(normalized)
                    }
                    "setBrightness" -> {
                        val value = call.argument<Double>("value")?.toFloat() ?: 0.5f
                        val lp = window.attributes
                        lp.screenBrightness = value.coerceIn(0.02f, 1f)
                        window.attributes = lp
                        result.success(null)
                    }
                    "getVolume" -> {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        result.success(mapOf("volume" to current, "max" to max))
                    }
                    "setVolume" -> {
                        val volume = call.argument<Int>("volume") ?: 0
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_MUSIC,
                            volume.coerceIn(0, max),
                            0,
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_ID_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidId" -> {
                        try {
                            val id = Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID,
                            ) ?: ""
                            result.success(id)
                        } catch (e: Exception) {
                            result.error("ANDROID_ID_ERROR", e.message, null)
                        }
                    }
                    "getUserAgent" -> {
                        try {
                            val model = Build.MODEL?.trim().orEmpty().ifEmpty { "Android" }
                            val manufacturer = Build.MANUFACTURER?.trim().orEmpty()
                            val deviceLabel = when {
                                manufacturer.isEmpty() -> model
                                model.startsWith(manufacturer, ignoreCase = true) -> model
                                else -> "$manufacturer $model"
                            }
                            val release = Build.VERSION.RELEASE?.trim().orEmpty().ifEmpty { "10" }
                            val ua = "Mozilla/5.0 (Linux; Android $release; $deviceLabel) " +
                                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 VideoWebApp/1.0"
                            result.success(ua)
                        } catch (e: Exception) {
                            result.error("USER_AGENT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val CHANNEL = "com.video.videoweb/live_gift_svga"
        private const val PLAYER_CONTROLS_CHANNEL = "com.video.videoweb/player_controls"
        private const val DEVICE_ID_CHANNEL = "com.video.videoweb/device_id"
        const val SVGA_VIEW_TYPE = "com.video.videoweb/live_gift_svga_view"
    }
}
