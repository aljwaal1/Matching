package com.explapp.matching

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
    }
}
