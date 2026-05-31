package com.bestfin.bestfin

import android.app.DownloadManager
import android.content.Context
import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.bestfin.bestfin/download_manager"

    companion object {
        init {
            // Load all llama.cpp native libraries with RTLD_GLOBAL so every
            // symbol (llama_*, ggml_*, mtmd_*) is visible to DynamicLibrary.process()
            // in Dart FFI. Loading order must respect the dependency chain.
            System.loadLibrary("c++_shared")
            System.loadLibrary("ggml-base")
            System.loadLibrary("ggml-cpu")
            System.loadLibrary("OpenCL")
            System.loadLibrary("ggml-opencl")
            System.loadLibrary("ggml")
            System.loadLibrary("llama")
            System.loadLibrary("mtmd")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    if (url == null || fileName == null) {
                        result.error("INVALID_ARGUMENTS", "URL or fileName is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val downloadId = startDownload(url, fileName)
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

    private fun startDownload(url: String, fileName: String): Long {
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
}
