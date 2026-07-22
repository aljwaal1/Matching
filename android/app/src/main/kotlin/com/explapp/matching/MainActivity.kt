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
                if (call.method != "writeAndVerify") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val location = call.argument<String>("location")
                val bytes = call.argument<ByteArray>("bytes")
                if (location.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                    result.error("INVALID_FILE", "بيانات الملف أو موقعه غير صالح", null)
                    return@setMethodCallHandler
                }
                try {
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
                        val size = contentResolver.openInputStream(uri).use { stream ->
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
                        result.success(size)
                    } else {
                        val file = File(uri.path ?: location)
                        file.outputStream().use { stream ->
                            stream.write(bytes)
                            stream.flush()
                        }
                        result.success(file.length())
                    }
                } catch (error: Exception) {
                    result.error("FILE_WRITE_FAILED", error.message, null)
                }
            }
    }
}
