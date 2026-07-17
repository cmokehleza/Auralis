package com.example.flutter_application_1

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.auralis.player/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(intent, "Share track"))
                result.success(true)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.auralis.player/widget")
            .setMethodCallHandler { call, result ->
                if (call.method != "update") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val data = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                AuralisWidgetProvider.storeAndRefresh(
                    this,
                    title = data["title"] as? String ?: "Nothing playing",
                    artist = data["artist"] as? String ?: "Auralis",
                    positionMs = (data["positionMs"] as? Number)?.toInt() ?: 0,
                    durationMs = (data["durationMs"] as? Number)?.toInt() ?: 1,
                    playing = data["playing"] as? Boolean ?: false,
                    artwork = data["artwork"] as? ByteArray,
                    artworkProvided = data.containsKey("artwork"),
                )
                result.success(true)
            }
    }
}
