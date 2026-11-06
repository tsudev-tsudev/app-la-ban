package com.tsudev.laban

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // M2b (Q66): chuyển dữ liệu sang La bàn Pro.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "la_ban/chuyen_pro")
            .setMethodCallHandler(KenhChuyenPro(this))
    }
}
