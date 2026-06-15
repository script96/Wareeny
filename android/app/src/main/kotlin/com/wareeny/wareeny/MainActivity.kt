package com.wareeny.wareeny

import android.app.PendingIntent
import android.content.Intent
import android.telephony.SmsManager
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val emergencyChannel = "com.wareeny.bridge/emergency"
    private val volumeButtonChannel = "com.wareeny.bridge/volume_button_trigger"
    private var volumeEventSink: EventChannel.EventSink? = null
    private var volumeUpPressed = false
    private var volumeDownPressed = false
    private var volumeComboDelivered = false

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

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            volumeButtonChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                volumeEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                volumeEventSink = null
            }
        })
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (event.repeatCount == 0) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> volumeUpPressed = true
                KeyEvent.KEYCODE_VOLUME_DOWN -> volumeDownPressed = true
            }
            if (volumeUpPressed && volumeDownPressed && !volumeComboDelivered) {
                volumeComboDelivered = true
                volumeEventSink?.success("both_volume_buttons")
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> volumeUpPressed = false
            KeyEvent.KEYCODE_VOLUME_DOWN -> volumeDownPressed = false
        }
        if (!volumeUpPressed || !volumeDownPressed) {
            volumeComboDelivered = false
        }
        return super.onKeyUp(keyCode, event)
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
