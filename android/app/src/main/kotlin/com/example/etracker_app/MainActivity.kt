package com.example.etracker_app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
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

                    // ── Start background location service ──────────────
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

                    // ── Stop background location service ───────────────
                    "stopService" -> {
                        // Clear active flag — BootReceiver + WorkManager won't restart
                        val prefs = getSharedPreferences(LocationService.PREF_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putBoolean(LocationService.KEY_ACTIVE, false).apply()

                        // Cancel WorkManager rescue so it stops trying to restart
                        WorkManager.getInstance(applicationContext)
                            .cancelAllWorkByTag("etracker_rescue")

                        val intent = Intent(this, LocationService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    // ── Read native battery level ──────────────────────
                    // Flutter's battery_plus can fail in background; this
                    // gives Flutter a reliable native fallback via MethodChannel.
                    "getBatteryLevel" -> {
                        val battery = getNativeBatteryLevel()
                        result.success(battery)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Native battery level reader ───────────────────────────────
    private fun getNativeBatteryLevel(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val bm    = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (level == Integer.MIN_VALUE || level < 0) -1 else level
            } else {
                val intent = registerReceiver(
                    null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                )
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level == -1 || scale == -1) -1 else (level * 100 / scale)
            }
        } catch (e: Exception) {
            -1
        }
    }
}
