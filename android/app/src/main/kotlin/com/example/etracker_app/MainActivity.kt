package com.example.etracker_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class FlutterBridge {
    companion object {
        var userId: Int = 0
        var serverUrl: String = ""
    }
}

class MainActivity : FlutterActivity() {

    private val CHANNEL = "etracker_channel"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "startService" -> {

                        val userId = call.argument<Int>("user_id") ?: -1
                        val serverUrl = call.argument<String>("serverUrl") ?: ""

                        if (userId == -1 || serverUrl.isEmpty()) {
                            result.error("INVALID_DATA", "Missing user_id or serverUrl", null)
                            return@setMethodCallHandler
                        }

                        FlutterBridge.userId = userId
                        FlutterBridge.serverUrl = serverUrl

                        val intent = Intent(this, LocationService::class.java).apply {
                            putExtra("user_id", userId)
                            putExtra("serverUrl", serverUrl)
                        }

                        startForegroundService(intent)
                        result.success(true)
                    }

                    "stopService" -> {
                        val intent = Intent(this, LocationService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
