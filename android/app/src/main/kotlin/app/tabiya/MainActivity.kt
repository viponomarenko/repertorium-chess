package app.tabiya

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives files and text from other apps ("Open with", "Share") and hands
 * them to Dart over the `app.tabiya/incoming` channel (F-IMP-02).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val pending = mutableListOf<Map<String, Any?>>()
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.tabiya/incoming")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitial" -> {
                    dartReady = true
                    result.success(ArrayList(pending))
                    pending.clear()
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val payload: Map<String, Any?> = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { readUri(it) }
            Intent.ACTION_SEND -> {
                val stream: Uri? = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
                if (stream != null) readUri(stream)
                else intent.getStringExtra(Intent.EXTRA_TEXT)?.let { mapOf("text" to it) }
            }
            else -> null
        } ?: return
        // Do not process the same intent twice (e.g. after rotation).
        intent.action = null
        if (dartReady) channel?.invokeMethod("incoming", payload) else pending.add(payload)
    }

    private fun readUri(uri: Uri): Map<String, Any?>? {
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val data = input.readBytes()
                if (data.size > MAX_BYTES) null else data
            } ?: return null
            mapOf("bytes" to bytes, "name" to (displayName(uri) ?: uri.lastPathSegment))
        } catch (e: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme != "content") return null
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val MAX_BYTES = 64 * 1024 * 1024
    }
}
