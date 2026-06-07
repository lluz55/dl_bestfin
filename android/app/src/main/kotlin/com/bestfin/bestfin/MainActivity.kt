package com.bestfin.bestfin

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import com.bestfin.bestfin.llm.LiteRtLlmBridge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.bestfin.bestfin/download_manager"
    private val SHARE_CHANNEL = "com.bestfin.bestfin/share_receiver"
    private var liteRtBridge: LiteRtLlmBridge? = null

    private var sharedText: String? = null
    private var sharedImageUri: String? = null

    companion object {
        init {
            try {
                // Legacy llama.cpp fallback. LiteRT-LM is the default Android
                // backend, so missing GGML libraries must not abort startup.
                System.loadLibrary("c++_shared")
                System.loadLibrary("ggml-base")
                System.loadLibrary("ggml-cpu")
                System.loadLibrary("OpenCL")
                System.loadLibrary("ggml-opencl")
                System.loadLibrary("ggml")
                System.loadLibrary("llama")
                System.loadLibrary("mtmd")
            } catch (_: UnsatisfiedLinkError) {
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = LiteRtLlmBridge(applicationContext)
        liteRtBridge = bridge
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.bestfin.bestfin/litert_lm"
        ).setMethodCallHandler(bridge)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.bestfin.bestfin/litert_lm_stream"
        ).setStreamHandler(bridge)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSharedData") {
                val data = mutableMapOf<String, String?>()
                data["text"] = sharedText
                data["imageUri"] = sharedImageUri
                result.success(data)
                
                sharedText = null
                sharedImageUri = null
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                    if (url == null || fileName == null) {
                        result.error("INVALID_ARGUMENTS", "URL or fileName is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val downloadId = startDownload(url, fileName, headers)
                        result.success(downloadId)
                    } catch (e: Exception) {
                        result.error("DOWNLOAD_ERROR", e.message, null)
                    }
                }
                "getDownloadProgress" -> {
                    val downloadId = (call.argument<Any>("downloadId") as? Number)?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGUMENTS", "downloadId is null", null)
                        return@setMethodCallHandler
                    }
                    val progress = getDownloadProgress(downloadId)
                    result.success(progress)
                }
                "cancelDownload" -> {
                    val downloadId = (call.argument<Any>("downloadId") as? Number)?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGUMENTS", "downloadId is null", null)
                        return@setMethodCallHandler
                    }
                    val removed = cancelDownload(downloadId)
                    result.success(removed)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        liteRtBridge?.close()
        liteRtBridge = null
        super.onDestroy()
    }

    private fun startDownload(url: String, fileName: String, headers: Map<String, String>): Long {
        val extDir = getExternalFilesDir(null)
        if (extDir != null) {
            val llmDir = File(extDir, "llm")
            if (!llmDir.exists()) {
                llmDir.mkdirs()
            }
            val targetFile = File(llmDir, fileName)
            if (targetFile.exists()) {
                targetFile.delete()
            }
        }

        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI or DownloadManager.Request.NETWORK_MOBILE)
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setTitle("Baixando modelo de IA")
            setDescription(fileName)
            setDestinationInExternalFilesDir(this@MainActivity, null, "llm/$fileName")
            headers.forEach { (name, value) ->
                if (name.isNotBlank() && value.isNotBlank()) {
                    addRequestHeader(name, value)
                }
            }
        }
        return downloadManager.enqueue(request)
    }

    private fun getDownloadProgress(downloadId: Long): Map<String, Any?> {
        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        val cursor: Cursor? = downloadManager.query(query)
        val result = mutableMapOf<String, Any?>()

        if (cursor != null && cursor.moveToFirst()) {
            val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
            val bytesDownloadedIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val bytesTotalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            val reasonIdx = cursor.getColumnIndex(DownloadManager.COLUMN_REASON)

            val status = if (statusIdx >= 0) cursor.getInt(statusIdx) else -1
            val bytesDownloaded = if (bytesDownloadedIdx >= 0) cursor.getLong(bytesDownloadedIdx) else 0L
            val bytesTotal = if (bytesTotalIdx >= 0) cursor.getLong(bytesTotalIdx) else 0L
            val reason = if (reasonIdx >= 0) cursor.getInt(reasonIdx) else 0

            val statusString = when (status) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "unknown"
            }

            result["status"] = statusString
            result["bytesDownloaded"] = bytesDownloaded
            result["bytesTotal"] = bytesTotal
            result["reason"] = reason

            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                val localUriIdx = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
                if (localUriIdx >= 0) {
                    val localUriStr = cursor.getString(localUriIdx)
                    if (localUriStr != null) {
                        result["localUri"] = localUriStr
                    }
                }
            }
        } else {
            result["status"] = "unknown"
        }
        cursor?.close()
        return result
    }

    private fun cancelDownload(downloadId: Long): Boolean {
        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return downloadManager.remove(downloadId) > 0
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        when (action) {
            Intent.ACTION_SEND -> {
                if ("text/plain" == type) {
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                } else if (type != null && type.startsWith("image/")) {
                    val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (imageUri != null) {
                        sharedImageUri = copyUriToCache(imageUri)
                    }
                }
            }
            Intent.ACTION_PROCESS_TEXT -> {
                if ("text/plain" == type) {
                    sharedText = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val cacheFile = File(cacheDir, "shared_image.jpg")
            FileOutputStream(cacheFile).use { outputStream ->
                inputStream.use { input ->
                    input.copyTo(outputStream)
                }
            }
            cacheFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
