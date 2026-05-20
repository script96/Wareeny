package com.example.warene

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "warene/depth/arcore"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(false)
                "estimateDepth" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}
