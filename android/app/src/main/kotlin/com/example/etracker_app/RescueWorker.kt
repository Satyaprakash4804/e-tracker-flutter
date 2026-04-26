package com.example.etracker_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * RescueWorker — scheduled by WorkManager every 15 minutes.
 *
 * Purpose: On aggressive OEM devices (Xiaomi MIUI, Oppo ColorOS, Realme,
 * Samsung OneUI with aggressive battery saver), the Android OS kills
 * foreground services and ignores START_STICKY.
 *
 * WorkManager jobs survive this because they are backed by JobScheduler
 * (Android 5+), which the OS guarantees will run on a best-effort basis
 * even after the app process is killed.
 *
 * This worker simply checks if the user had tracking active and restarts
 * LocationService if it is no longer running.
 */
class RescueWorker(
    private val context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "RescueWorker"
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
            Log.d(TAG, "Tracking not active — skipping restart")
            return Result.success()
        }

        // Check if service is already running — if so, no action needed
        if (isServiceRunning()) {
            Log.d(TAG, "Service already running — no restart needed")
            return Result.success()
        }

        Log.d(TAG, "Service not running — restarting now")

        // Restart the foreground service with credentials from SharedPrefs.
        // Intent extras are not strictly necessary (service reads from SharedPrefs
        // on null intent), but including them avoids an extra SharedPrefs read.
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

        return Result.success()
    }

    /**
     * Check if LocationService is currently running by inspecting
     * the ActivityManager's list of running services.
     * Note: getRunningServices is deprecated for 3rd-party apps on API 26+
     * but still works for your own app's services.
     */
    @Suppress("DEPRECATION")
    private fun isServiceRunning(): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE)
            as android.app.ActivityManager
        return manager.getRunningServices(Int.MAX_VALUE)
            .any { it.service.className == LocationService::class.java.name }
    }
}