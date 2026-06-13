package com.wareeny.wareeny

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val emergencyChannel = "com.wareeny.bridge/emergency"
    private val callPermissionRequest = 4102
    private var pendingPhoneNumber: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            emergencyChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "call.start") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val phoneNumber = call.argument<String>("phoneNumber")
            if (phoneNumber.isNullOrBlank()) {
                result.error("invalid_phone", "A phone number is required.", null)
                return@setMethodCallHandler
            }
            startEmergencyContactCall(phoneNumber, result)
        }
    }

    private fun startEmergencyContactCall(
        phoneNumber: String,
        result: MethodChannel.Result,
    ) {
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(placeCall(phoneNumber))
            return
        }

        pendingPhoneNumber = phoneNumber
        pendingResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CALL_PHONE),
            callPermissionRequest,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != callPermissionRequest) return

        val result = pendingResult
        val phoneNumber = pendingPhoneNumber
        pendingResult = null
        pendingPhoneNumber = null
        if (result == null || phoneNumber == null) return

        if (
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(placeCall(phoneNumber))
        } else {
            result.success(false)
        }
    }

    private fun placeCall(phoneNumber: String): Boolean {
        return try {
            startActivity(
                Intent(Intent.ACTION_CALL, Uri.parse("tel:$phoneNumber")),
            )
            true
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }
}
