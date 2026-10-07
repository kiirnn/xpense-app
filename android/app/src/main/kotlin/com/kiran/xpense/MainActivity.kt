package com.kiran.xpense

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Hosts a tiny "xpense/files" channel that saves and opens documents through
/// Android's Storage Access Framework, so backups need no extra plugin.
class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val SAVE = 4101
        const val OPEN = 4102
    }

    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xpense/files").setMethodCallHandler { call, result ->
            if (pending != null) {
                result.error("busy", "Another file dialog is open", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "save" -> {
                    pending = result
                    pendingBytes = call.argument<ByteArray>("bytes")
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("mime") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                    }
                    startActivityForResult(intent, SAVE)
                }
                "open" -> {
                    pending = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "application/octet-stream", "text/plain"))
                    }
                    startActivityForResult(intent, OPEN)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE && requestCode != OPEN) return
        val result = pending ?: return
        val bytes = pendingBytes
        pending = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            if (requestCode == SAVE) {
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes ?: ByteArray(0)) }
                result.success(true)
            } else {
                val text = contentResolver.openInputStream(uri)!!.use { it.readBytes().toString(Charsets.UTF_8) }
                result.success(text)
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }
}
