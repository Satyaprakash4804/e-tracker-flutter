package com.example.etracker_app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.work.WorkManager

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
                        val userId    = call.argument<Int>("user_id") ?: -1
                        val serverUrl = call.argument<String>("serverUrl") ?: ""
                        val token     = call.argument<String>("token") ?: ""

                        if (userId == -1 || serverUrl.isEmpty()) {
                            result.error("INVALID_DATA", "Missing user_id or serverUrl", null)
                            return@setMethodCallHandler
                        }

                        FlutterBridge.userId    = userId
                        FlutterBridge.serverUrl = serverUrl

                        // Save to SharedPreferences so service survives app kill
                        val prefs = getSharedPreferences(LocationService.PREF_NAME, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putInt(LocationService.KEY_USER_ID, userId)
                            .putString(LocationService.KEY_URL, serverUrl)
                            .putString(LocationService.KEY_TOKEN, token)
                            .putBoolean(LocationService.KEY_ACTIVE, true)
                            .apply()

                        val intent = Intent(this, LocationService::class.java).apply {
                            putExtra("user_id",   userId)
                            putExtra("serverUrl", serverUrl)
                            putExtra("token",     token)
                        }
                        startForegroundService(intent)
                        result.success(true)
                    }

                    "stopService" -> {
                        // Clear active flag — BootReceiver + WorkManager won't restart
                        val prefs = getSharedPreferences(LocationService.PREF_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putBoolean(LocationService.KEY_ACTIVE, false).apply()

                        // Cancel WorkManager rescue so it doesn't try to restart
                        WorkManager.getInstance(applicationContext)
                            .cancelAllWorkByTag("etracker_rescue")

                        val intent = Intent(this, LocationService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}