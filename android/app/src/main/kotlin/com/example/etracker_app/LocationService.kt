package com.example.etracker_app

import android.app.*
import android.content.*
import android.location.Location
import android.os.*
import android.content.pm.ServiceInfo
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import com.google.android.gms.location.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LocationService : Service() {

    private lateinit var fusedClient: FusedLocationProviderClient

    // OkHttpClient with timeouts — prevents infinite hangs on bad network
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    // Battery manager — used to read battery level on every location update
    private lateinit var batteryManager: BatteryManager

    companion object {
        const val PREF_NAME        = "etracker_prefs"
        const val KEY_USER_ID      = "user_id"
        const val KEY_URL          = "server_url"
        const val KEY_TOKEN        = "token"
        const val KEY_ACTIVE       = "tracking_active"
        const val KEY_LAST_BATTERY = "last_battery"
        private const val TAG      = "LocationService"
        const val NOTIF_ID         = 101
        const val CHANNEL_ID       = "etracker_location_channel"
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient    = LocationServices.getFusedLocationProviderClient(this)
        batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        Log.d(TAG, "Service onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand — intent null: ${intent == null}")

        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

        val userId: Int
        val serverUrl: String
        val token: String

        if (intent != null && intent.hasExtra("user_id")) {
            // Called from Flutter (startService) or BootReceiver
            userId    = intent.getIntExtra("user_id", -1)
            serverUrl = intent.getStringExtra("serverUrl") ?: ""
            token     = intent.getStringExtra("token") ?: ""
        } else {
            // Android restarted service after kill (START_STICKY) — read from SharedPrefs
            userId    = prefs.getInt(KEY_USER_ID, -1)
            serverUrl = prefs.getString(KEY_URL, "") ?: ""
            token     = prefs.getString(KEY_TOKEN, "") ?: ""
        }

        Log.d(TAG, "userId=$userId  serverUrl=$serverUrl  hasToken=${token.isNotEmpty()}")

        if (userId == -1 || serverUrl.isEmpty()) {
            Log.w(TAG, "Missing credentials — stopping self")
            stopSelf()
            return START_NOT_STICKY
        }

        // Persist so the next restart (START_STICKY or WorkManager) can read them
        prefs.edit()
            .putInt(KEY_USER_ID, userId)
            .putString(KEY_URL, serverUrl)
            .putString(KEY_TOKEN, token)
            .putBoolean(KEY_ACTIVE, true)
            .apply()

        FlutterBridge.userId    = userId
        FlutterBridge.serverUrl = serverUrl

        startForegroundNotification()
        startLocationUpdates()

        // Schedule WorkManager rescue job every 15 minutes.
        // This is the ONLY mechanism that survives OEM aggressive kill
        // (Xiaomi MIUI, Oppo ColorOS, Samsung OneUI battery saver).
        scheduleWorkManagerRescue()

        return START_STICKY
    }

    // ── WorkManager rescue ────────────────────────────────────────
    private fun scheduleWorkManagerRescue() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = PeriodicWorkRequestBuilder<RescueWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .addTag("etracker_rescue")
            .build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "etracker_rescue",
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
        Log.d(TAG, "WorkManager rescue scheduled")
    }

    // ── Called when user swipes app from Recents ──────────────────
    // stopWithTask="false" in manifest means service keeps running.
    // This method fires to let us schedule a safety-net restart.
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "onTaskRemoved — scheduling one-time rescue worker")

        // Queue a one-time RescueWorker with a short delay.
        // No AlarmManager (requires special permission on API 31+).
        // If the process is still alive, Handler would work, but
        // WorkManager is more reliable across OEMs.
        val oneTime = OneTimeWorkRequestBuilder<RescueWorker>()
            .setInitialDelay(5, TimeUnit.SECONDS)
            .addTag("etracker_rescue_immediate")
            .build()
        WorkManager.getInstance(applicationContext).enqueue(oneTime)
    }

    // ── Foreground notification ───────────────────────────────────
    private fun startForegroundNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID,
                "E-Tracker Background Location",
                NotificationManager.IMPORTANCE_LOW
            ).apply { enableLights(false); enableVibration(false) }
            manager.createNotificationChannel(chan)
        }

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingOpen   = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("E-Tracker Active")
            .setContentText("Location tracking is running in background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingOpen)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    // ── FusedLocation updates ─────────────────────────────────────
    private fun startLocationUpdates() {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 8_000L)
            .setMinUpdateIntervalMillis(5_000L)
            .setMinUpdateDistanceMeters(5f)
            .build()

        try {
            fusedClient.requestLocationUpdates(request, locationCallback, mainLooper)
            Log.d(TAG, "Location updates requested")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission missing: ${e.message}")
            stopSelf()
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location: Location = result.lastLocation ?: return
            sendLocationToServer(location.latitude, location.longitude)
        }
    }

    // ── Read battery level ────────────────────────────────────────
    private fun getBatteryLevel(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                // -1 means the value is unknown
                if (level == Integer.MIN_VALUE || level < 0) -1 else level
            } else {
                // Fallback for very old devices via broadcast
                val intent = applicationContext.registerReceiver(
                    null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                )
                val level  = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale  = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level == -1 || scale == -1) -1 else (level * 100 / scale)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Battery read error: ${e.message}")
            -1
        }
    }

    // ── Send location + battery to backend ────────────────────────
    private fun sendLocationToServer(lat: Double, lng: Double) {
        val prefs        = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val currentToken = prefs.getString(KEY_TOKEN, "") ?: ""
        val currentUrl   = prefs.getString(KEY_URL,   "") ?: ""
        val currentUid   = prefs.getInt(KEY_USER_ID,  -1)

        if (currentUrl.isEmpty() || currentUid == -1) {
            Log.w(TAG, "sendLocation: missing credentials, skipping")
            return
        }

        // Read battery level on every update and cache it
        val battery = getBatteryLevel()
        if (battery != -1) {
            prefs.edit().putInt(KEY_LAST_BATTERY, battery).apply()
        }
        val cachedBattery = prefs.getInt(KEY_LAST_BATTERY, -1)

        // Build correct endpoint URL
        // serverUrl is stored as "http://ip:port" (no /api suffix)
        val cleanBase = currentUrl.trimEnd('/')
        val apiBase   = if (cleanBase.endsWith("/api")) cleanBase else "$cleanBase/api"
        val endpoint  = "$apiBase/location/update"

        Log.d(TAG, "→ $endpoint  uid=$currentUid  lat=$lat  lng=$lng  bat=$cachedBattery")

        val json = JSONObject().apply {
            put("user_id",   currentUid)
            put("latitude",  lat)
            put("longitude", lng)
            // Send battery even if -1 — backend should handle gracefully
            if (cachedBattery != -1) put("battery", cachedBattery)
        }

        val body = json.toString().toRequestBody("application/json".toMediaTypeOrNull())

        val requestBuilder = Request.Builder()
            .url(endpoint)
            .post(body)

        if (currentToken.isNotEmpty()) {
            requestBuilder.addHeader("Authorization", "Bearer $currentToken")
        }

        http.newCall(requestBuilder.build()).enqueue(object : Callback {
            override fun onFailure(call: Call, e: java.io.IOException) {
                Log.w(TAG, "Location send failed: ${e.message}")
            }
            override fun onResponse(call: Call, response: Response) {
                Log.d(TAG, "HTTP ${response.code}  bat=$cachedBattery")
                response.close()
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedClient.removeLocationUpdates(locationCallback)
        Log.d(TAG, "Service onDestroy")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
