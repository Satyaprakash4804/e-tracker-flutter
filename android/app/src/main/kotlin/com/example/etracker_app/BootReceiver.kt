package com.example.etracker_app

import android.content.*
import android.os.Build
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        val validActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )
        if (action !in validActions) return

        Log.d(TAG, "Boot completed — checking tracking state")

        val prefs     = context.getSharedPreferences(LocationService.PREF_NAME, Context.MODE_PRIVATE)
        val wasActive = prefs.getBoolean(LocationService.KEY_ACTIVE, false)
        val userId    = prefs.getInt(LocationService.KEY_USER_ID, -1)
        val serverUrl = prefs.getString(LocationService.KEY_URL, "") ?: ""
        val token     = prefs.getString(LocationService.KEY_TOKEN, "") ?: ""

        if (!wasActive || userId == -1 || serverUrl.isEmpty()) {
            Log.d(TAG, "Tracking not active — skipping")
            return
        }

        Log.d(TAG, "Restarting tracking after boot: userId=$userId")

        // Start the foreground service
        val serviceIntent = Intent(context, LocationService::class.java).apply {
            putExtra("user_id",   userId)
            putExtra("serverUrl", serverUrl)
            putExtra("token",     token)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // Also re-schedule the WorkManager rescue job after boot
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = PeriodicWorkRequestBuilder<RescueWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .addTag("etracker_rescue")
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "etracker_rescue",
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )

        Log.d(TAG, "Service and WorkManager rescue scheduled after boot")
    }
}