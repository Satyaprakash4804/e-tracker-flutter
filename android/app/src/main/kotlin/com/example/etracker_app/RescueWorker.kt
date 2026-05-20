package com.example.etracker_app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * RescueWorker — runs via WorkManager every 15 minutes.
 *
 * Why WorkManager?
 * ─────────────────
 * On aggressive OEM devices (Xiaomi MIUI, Oppo ColorOS, Realme, Samsung
 * OneUI with battery saver), Android kills foreground services and ignores
 * START_STICKY. WorkManager jobs are backed by JobScheduler which the OS
 * guarantees will run on a best-effort basis — even after app kill.
 *
 * What it does:
 * 1. Checks if user had tracking active (SharedPrefs flag)
 * 2. If LocationService is not running → restarts it
 * 3. Sends a standalone battery-level update to the backend
 *    so the admin always sees current battery even between location updates
 */
class RescueWorker(
    private val context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "RescueWorker"

        // Shared OkHttpClient — reused across calls, not recreated every run
        private val http = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()
    }

    override fun doWork(): Result {
        Log.d(TAG, "RescueWorker fired")

        val prefs     = context.getSharedPreferences(LocationService.PREF_NAME, Context.MODE_PRIVATE)
        val wasActive = prefs.getBoolean(LocationService.KEY_ACTIVE, false)
        val userId    = prefs.getInt(LocationService.KEY_USER_ID, -1)
        val serverUrl = prefs.getString(LocationService.KEY_URL, "") ?: ""
        val token     = prefs.getString(LocationService.KEY_TOKEN, "") ?: ""

        Log.d(TAG, "wasActive=$wasActive  userId=$userId  hasUrl=${serverUrl.isNotEmpty()}")

        if (!wasActive || userId == -1 || serverUrl.isEmpty()) {
            Log.d(TAG, "Tracking not active — skipping")
            return Result.success()
        }

        // 1. Restart service if it died
        if (!isServiceRunning()) {
            Log.d(TAG, "Service dead — restarting")
            val intent = Intent(context, LocationService::class.java).apply {
                putExtra("user_id",   userId)
                putExtra("serverUrl", serverUrl)
                putExtra("token",     token)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                Log.d(TAG, "Service restart triggered")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service: ${e.message}")
                return Result.retry()
            }
        } else {
            Log.d(TAG, "Service already running")
        }

        // 2. Send a standalone battery update
        // This ensures the admin sees updated battery even if the GPS
        // location hasn't changed (no movement = no location callback).
        val battery = getBatteryLevel()
        if (battery != -1 && userId != -1 && serverUrl.isNotEmpty()) {
            // Cache latest battery in SharedPrefs
            prefs.edit().putInt(LocationService.KEY_LAST_BATTERY, battery).apply()
            sendBatteryUpdate(userId, serverUrl, token, battery)
        }

        return Result.success()
    }

    // ── Read current battery level ────────────────────────────────
    private fun getBatteryLevel(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val bm    = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (level == Integer.MIN_VALUE || level < 0) -1 else level
            } else {
                val intent = context.registerReceiver(
                    null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                )
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level == -1 || scale == -1) -1 else (level * 100 / scale)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Battery read failed: ${e.message}")
            -1
        }
    }

    // ── POST battery level to /api/battery/update ─────────────────
    // Your backend should have this endpoint (or modify to use location/update)
    private fun sendBatteryUpdate(userId: Int, serverUrl: String, token: String, battery: Int) {
        val cleanBase = serverUrl.trimEnd('/')
        val apiBase   = if (cleanBase.endsWith("/api")) cleanBase else "$cleanBase/api"
        val endpoint  = "$apiBase/battery/update"

        Log.d(TAG, "Battery update → $endpoint  uid=$userId  bat=$battery%")

        val json = JSONObject().apply {
            put("user_id", userId)
            put("battery", battery)
        }

        val body = json.toString().toRequestBody("application/json".toMediaTypeOrNull())

        val requestBuilder = Request.Builder()
            .url(endpoint)
            .post(body)

        if (token.isNotEmpty()) {
            requestBuilder.addHeader("Authorization", "Bearer $token")
        }

        try {
            // Synchronous call inside Worker is fine — Worker runs on background thread
            val response = http.newCall(requestBuilder.build()).execute()
            Log.d(TAG, "Battery update HTTP ${response.code}")
            response.close()
        } catch (e: Exception) {
            // Non-fatal — don't fail the worker over a battery update
            Log.w(TAG, "Battery update failed: ${e.message}")
        }
    }

    // ── Check if LocationService is running ───────────────────────
    @Suppress("DEPRECATION")
    private fun isServiceRunning(): Boolean {
        return try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE)
                as android.app.ActivityManager
            manager.getRunningServices(Int.MAX_VALUE)
                .any { it.service.className == LocationService::class.java.name }
        } catch (e: Exception) {
            Log.w(TAG, "isServiceRunning check failed: ${e.message}")
            false // Assume not running — safer to restart
        }
    }
}
