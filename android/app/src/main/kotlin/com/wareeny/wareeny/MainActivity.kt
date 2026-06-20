package com.wareeny.wareeny

import android.telephony.SmsManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val emergencyChannel = "com.wareeny.bridge/emergency"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            emergencyChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sms.send" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val body  = call.argument<String>("body")  ?: ""
                    try {
                        sendSmsDirectly(phone, body)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Sends an SMS directly using Android [SmsManager] — no user interaction required.
     * Requires SEND_SMS permission to be granted.
     */
    @Suppress("DEPRECATION")
    private fun sendSmsDirectly(phone: String, body: String) {
        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            applicationContext.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }

        // Split into multiple parts if message is long (> 160 chars).
        val parts = smsManager.divideMessage(body)
        if (parts.size == 1) {
            smsManager.sendTextMessage(phone, null, body, null, null)
        } else {
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
        }
    }
}
