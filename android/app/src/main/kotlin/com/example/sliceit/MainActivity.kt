package com.example.sliceit

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sliceit/upi"
    private val UPI_REQUEST_CODE = 2025
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUpiPayment" -> {
                    if (pendingResult != null) {
                        result.error("ALREADY_ACTIVE", "Another UPI flow is active", null)
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *>
                    val upiId = (args?.get("upiId") as? String)?.trim()
                    val payeeName = (args?.get("payeeName") as? String)?.trim() ?: "SliceIt User"
                    val note = (args?.get("note") as? String)?.trim() ?: "Split settlement"
                    val amount = (args?.get("amount") as? Number)?.toDouble() ?: 0.0

                    if (upiId.isNullOrEmpty() || amount <= 0.0) {
                        result.error("BAD_ARGS", "upiId and amount are required", null)
                        return@setMethodCallHandler
                    }

                    val uri = Uri.parse(
                        "upi://pay?pa=" + Uri.encode(upiId) +
                                "&pn=" + Uri.encode(payeeName) +
                                "&am=" + String.format("%.2f", amount) +
                                "&cu=INR&tn=" + Uri.encode(note)
                    )

                    val intent = Intent(Intent.ACTION_VIEW, uri)
                    pendingResult = result
                    try {
                        startActivityForResult(intent, UPI_REQUEST_CODE)
                    } catch (e: ActivityNotFoundException) {
                        pendingResult = null
                        result.error("NO_UPI_APP", "No UPI app found to handle payment", null)
                    } catch (t: Throwable) {
                        pendingResult = null
                        result.error("INTENT_ERROR", t.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != UPI_REQUEST_CODE) return
        val res = pendingResult ?: return
        pendingResult = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            val response = (data.getStringExtra("response") ?: "").trim()
            val status = parseStatus(response)
            res.success(mapOf("status" to status, "raw" to response))
        } else if (resultCode == Activity.RESULT_CANCELED) {
            res.success(mapOf("status" to "cancelled", "raw" to ""))
        } else {
            res.success(mapOf("status" to "unknown", "raw" to ""))
        }
    }

    private fun parseStatus(resp: String): String {
        val lower = resp.lowercase()
        return when {
            lower.contains("success") -> "success"
            lower.contains("submitted") || lower.contains("pending") -> "submitted"
            lower.contains("failure") || lower.contains("failed") || lower.contains("cancel") -> "failure"
            else -> "unknown"
        }
    }
}
