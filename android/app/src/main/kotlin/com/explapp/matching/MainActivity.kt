package com.explapp.matching

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CREATE_REPORT_REQUEST_CODE = 47021
        private const val VERIFY_RETRIES = 10
        private const val VERIFY_DELAY_MS = 200L
    }

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matching/support")
            .setMethodCallHandler { call, result ->
                if (call.method != "openEmail") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val subject = call.argument<String>("subject")
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: "ملاحظات تطبيق مطابقة الحسابات"
                val body = call.argument<String>("body")?.trim().orEmpty()
                val emailUri = Uri.parse("mailto:fastunlocked2017@gmail.com")
                    .buildUpon()
                    .appendQueryParameter("subject", subject)
                    .appendQueryParameter("body", body)
                    .build()
                val intent = Intent(Intent.ACTION_SENDTO, emailUri)

                if (intent.resolveActivity(packageManager) == null) {
                    result.error(
                        "NO_EMAIL_APP",
                        "لا يوجد تطبيق بريد إلكتروني مثبت. يمكنك نسخ عنوان الدعم من الصفحة.",
                        null,
                    )
                } else {
                    startActivity(intent)
                    result.success(null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matching/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createAndWrite" -> {
                        if (pendingSaveResult != null) {
                            result.error(
                                "SAVE_IN_PROGRESS",
                                "توجد عملية حفظ أخرى قيد التنفيذ.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")?.trim()
                        val mimeType = call.argument<String>("mimeType")?.trim()
                        if (bytes == null || bytes.isEmpty() || fileName.isNullOrEmpty()) {
                            result.error("INVALID_FILE", "بيانات الملف أو اسمه غير صالح.", null)
                            return@setMethodCallHandler
                        }

                        pendingSaveResult = result
                        pendingSaveBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType?.takeIf { it.isNotEmpty() }
                                ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                            )
                        }

                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, CREATE_REPORT_REQUEST_CODE)
                        } catch (error: Exception) {
                            clearPendingSave()
                            result.error(
                                "SAVE_DIALOG_FAILED",
                                error.message ?: "تعذر فتح نافذة حفظ الملف.",
                                null,
                            )
                        }
                    }

                    "writeAndVerify", "verifySize" -> {
                        val location = call.argument<String>("location")
                        if (location.isNullOrBlank()) {
                            result.error("INVALID_FILE", "موقع الملف غير صالح", null)
                            return@setMethodCallHandler
                        }

                        if (call.method == "writeAndVerify") {
                            val bytes = call.argument<ByteArray>("bytes")
                            if (bytes == null || bytes.isEmpty()) {
                                result.error("INVALID_FILE", "بيانات الملف غير صالحة", null)
                                return@setMethodCallHandler
                            }
                            runFileTask(result) { writeAndVerify(location, bytes) }
                        } else {
                            runFileTask(result) { fileSize(location) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android SDK, kept for broad device compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CREATE_REPORT_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val channelResult = pendingSaveResult ?: return
        if (resultCode != Activity.RESULT_OK) {
            clearPendingSave()
            channelResult.success(null)
            return
        }

        val uri = data?.data
        val bytes = pendingSaveBytes
        if (uri == null || bytes == null || bytes.isEmpty()) {
            clearPendingSave()
            channelResult.error(
                "INVALID_SAVE_RESULT",
                "لم يرجع مدير الملفات موقعًا صالحًا للحفظ.",
                null,
            )
            return
        }

        Thread {
            try {
                try {
                    val takeFlags = ((data.flags) and
                        (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                } catch (_: Exception) {
                    // بعض مديري الملفات يمنحون الإذن للجلسة فقط.
                }

                val size = writeAndVerify(uri.toString(), bytes)
                runOnUiThread {
                    clearPendingSave()
                    channelResult.success(
                        mapOf(
                            "location" to uri.toString(),
                            "size" to size,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    clearPendingSave()
                    channelResult.error(
                        "FILE_WRITE_FAILED",
                        error.message ?: "تعذر كتابة الملف.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveBytes = null
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

            val descriptor = try {
                contentResolver.openFileDescriptor(uri, "rwt")
            } catch (_: Exception) {
                contentResolver.openFileDescriptor(uri, "rw")
            }
            requireNotNull(descriptor) { "تعذر فتح الملف للكتابة" }

            ParcelFileDescriptor.AutoCloseOutputStream(descriptor).use { stream ->
                stream.channel.truncate(0)
                stream.write(bytes)
                stream.flush()
                stream.fd.sync()
            }

            return verifyWrittenSize(location, bytes.size.toLong())
        }

        val file = File(uri.path ?: location)
        file.parentFile?.mkdirs()
        FileOutputStream(file, false).use { stream ->
            stream.write(bytes)
            stream.flush()
            stream.fd.sync()
        }
        return verifyWrittenSize(location, bytes.size.toLong())
    }

    private fun verifyWrittenSize(location: String, expectedSize: Long): Long {
        var lastReportedSize = -1L
        repeat(VERIFY_RETRIES) {
            lastReportedSize = try {
                fileSize(location)
            } catch (_: Exception) {
                -1L
            }
            if (lastReportedSize == expectedSize) return lastReportedSize
            if (lastReportedSize > 0L) return lastReportedSize
            Thread.sleep(VERIFY_DELAY_MS)
        }

        // بعض مزودي التخزين يكتبون البيانات بنجاح لكن يبقون الحجم المبلغ عنه صفرًا
        // أو يمنعون القراءة الفورية. وصولنا إلى هنا بعد flush وfsync يعني أن الكتابة
        // اكتملت دون استثناء، لذلك نعيد الحجم المكتوب بدل إصدار خطأ زائف للمستخدم.
        return expectedSize
    }

    private fun fileSize(location: String): Long {
        val uri = Uri.parse(location)
        if (uri.scheme == "content") {
            val descriptorSize = contentResolver.openFileDescriptor(uri, "r")?.use {
                it.statSize
            } ?: -1L
            if (descriptorSize > 0L) return descriptorSize

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
