package com.heyairu.monogatari_assistant_fe

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.heyairu.monogatari_assistant/file"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "writeToUri") {
                val uriString = call.argument<String>("uri")
                val content = call.argument<String>("content")

                if (uriString != null && content != null) {
                    try {
                        val uri = Uri.parse(uriString)
                        contentResolver.openOutputStream(uri, "wt")?.use { outputStream ->
                            outputStream.write(content.toByteArray(Charsets.UTF_8))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WRITE_ERROR", "Failed to write to URI: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "URI or content cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
