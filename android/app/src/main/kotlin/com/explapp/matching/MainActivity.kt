package com.explapp.matching

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matching/support")
            .setMethodCallHandler { call, result ->
                if (call.method != "openEmail") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val intent = Intent(
                    Intent.ACTION_SENDTO,
                    Uri.parse("mailto:fastunlocked2017@gmail.com?subject=${Uri.encode("ملاحظات تطبيق مطابقة الحسابات")}"),
                )
                if (intent.resolveActivity(packageManager) == null) {
                    result.error("NO_EMAIL_APP", "لا يوجد تطبيق بريد إلكتروني", null)
                } else {
                    startActivity(intent)
                    result.success(null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matching/files")
            .setMethodCallHandler { call, result ->
                val location = call.argument<String>("location")
                if (location.isNullOrBlank()) {
                    result.error("INVALID_FILE", "موقع الملف غير صالح", null)
                    return@setMethodCallHandler
                }

                when (call.method) {
                    "writeAndVerify" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_FILE", "بيانات الملف غير صالحة", null)
                            return@setMethodCallHandler
                        }
                        runFileTask(result) { writeAndVerify(location, bytes) }
                    }

                    "verifySize" -> runFileTask(result) { fileSize(location) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun runFileTask(
        result: MethodChannel.Result,
        action: () -> Long,
    ) {
        Thread {
            try {
                val size = action()
                runOnUiThread { result.success(size) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("FILE_WRITE_FAILED", error.message, null)
                }
            }
        }.start()
    }

    private fun writeAndVerify(location: String, bytes: ByteArray): Long {
        val uri = Uri.parse(location)
        if (uri.scheme == "content") {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // بعض مزودي الملفات يمنحون الإذن للجلسة فقط.
            }
            val output = try {
                contentResolver.openOutputStream(uri, "rwt")
            } catch (_: Exception) {
                contentResolver.openOutputStream(uri, "w")
            }
            output.use { stream ->
                requireNotNull(stream) { "تعذر فتح الملف للكتابة" }
                stream.write(bytes)
                stream.flush()
            }
            return fileSize(location)
        }

        val file = File(uri.path ?: location)
        file.parentFile?.mkdirs()
        file.outputStream().use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        return file.length()
    }

    private fun fileSize(location: String): Long {
        val uri = Uri.parse(location)
        if (uri.scheme == "content") {
            val descriptorSize = contentResolver.openFileDescriptor(uri, "r")?.use {
                it.statSize
            } ?: -1L
            if (descriptorSize >= 0L) return descriptorSize

            return contentResolver.openInputStream(uri).use { stream ->
                requireNotNull(stream) { "تعذر فتح الملف للتحقق" }
                var total = 0L
                val buffer = ByteArray(8192)
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) break
                    total += read
                }
                total
            }
        }

        return File(uri.path ?: location).length()
    }
}
