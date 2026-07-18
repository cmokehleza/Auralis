package com.example.flutter_application_1

import android.content.Intent
import android.app.Activity
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val saveFileRequestCode = 7421
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.auralis.player/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSaveResult != null) {
                    result.error("save_in_progress", "Another file is already being saved.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val suggestedName = call.argument<String>("suggestedName")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes == null || suggestedName.isNullOrBlank()) {
                    result.error("invalid_file", "File data or name is missing.", null)
                    return@setMethodCallHandler
                }
                pendingSaveResult = result
                pendingSaveBytes = bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, suggestedName)
                }
                startActivityForResult(intent, saveFileRequestCode)
            }
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

    @Deprecated("Deprecated in Android, retained for Android 11 compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != saveFileRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingSaveResult
        val bytes = pendingSaveBytes
        pendingSaveResult = null
        pendingSaveBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        try {
            val uri = data.data!!
            contentResolver.openOutputStream(uri, "w")?.use { stream ->
                stream.write(bytes ?: ByteArray(0))
                stream.flush()
            } ?: throw IllegalStateException("Could not open the selected document.")
            result?.success(uri.toString())
        } catch (error: Exception) {
            result?.error("save_failed", error.message, null)
        }
    }
}
