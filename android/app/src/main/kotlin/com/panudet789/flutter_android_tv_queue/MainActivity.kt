package com.panudet789.flutter_android_tv_queue

import android.content.res.Configuration
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ใช้โดย lib/helper/device_input.dart
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.panudet789.flutter_android_tv_queue/device_input",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasHardwareKeyboard" -> {
                    val config = resources.configuration
                    result.success(
                        config.keyboard == Configuration.KEYBOARD_QWERTY &&
                            config.hardKeyboardHidden == Configuration.HARDKEYBOARDHIDDEN_NO,
                    )
                }
                else -> result.notImplemented()
            }
        }

        // ใช้โดย lib/helper/screen_helper.dart — จอคิวเปิดทั้งวัน ห้ามดับ/เข้า screensaver
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.panudet789.flutter_android_tv_queue/screen",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
