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

    // FIX: OkHttpClient with timeouts — prevents infinite hangs on bad network
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    companion object {
        const val PREF_NAME   = "etracker_prefs"
        const val KEY_USER_ID = "user_id"
        const val KEY_URL     = "server_url"
        const val KEY_TOKEN   = "token"
        const val KEY_ACTIVE  = "tracking_active"
        private const val TAG = "LocationService"
        const val NOTIF_ID    = 101
        const val CHANNEL_ID  = "etracker_location_channel"
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        Log.d(TAG, "Service onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand — intent null: ${intent == null}")

        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

        val userId: Int
        val serverUrl: String
        val token: String

        if (intent != null && intent.hasExtra("user_id")) {
            userId    = intent.getIntExtra("user_id", -1)
            serverUrl = intent.getStringExtra("serverUrl") ?: ""
            token     = intent.getStringExtra("token") ?: ""
        } else {
            // Android restarted service after kill — read from SharedPrefs
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

        // Persist credentials so restarts can read them
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

        // FIX: Schedule WorkManager rescue job every 15 min.
        // If the service is killed by OEM (Xiaomi/Oppo/Samsung), WorkManager
        // will restart it even when START_STICKY is ignored.
        scheduleWorkManagerRescue()

        return START_STICKY
    }

    // ── WorkManager rescue scheduler ──────────────────────────────
    // WorkManager is the ONLY mechanism that survives OEM aggressive kill.
    // It runs RescueWorker every 15 minutes (minimum allowed by Android).
    // RescueWorker checks SharedPrefs and restarts the service if needed.
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
            ExistingPeriodicWorkPolicy.KEEP, // Don't replace an already-scheduled job
            request
        )
        Log.d(TAG, "WorkManager rescue scheduled")
    }

    // ── Called when user swipes app away from Recents ─────────────
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "onTaskRemoved — rescheduling WorkManager rescue")
        // WorkManager is already scheduled above; just ensure it runs soon
        // by also scheduling a one-time rescue after 5 seconds as a bridge.
        val oneTime = OneTimeWorkRequestBuilder<RescueWorker>()
            .setInitialDelay(5, TimeUnit.SECONDS)
            .addTag("etracker_rescue_immediate")
            .build()
        WorkManager.getInstance(applicationContext).enqueue(oneTime)
    }

    // ── Foreground notification ────────────────────────────────────
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

    // ── FusedLocation updates ──────────────────────────────────────
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

    // ── Send location to backend ───────────────────────────────────
    private fun sendLocationToServer(lat: Double, lng: Double) {
        val prefs        = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val currentToken = prefs.getString(KEY_TOKEN, "") ?: ""
        val currentUrl   = prefs.getString(KEY_URL,   "") ?: ""
        val currentUid   = prefs.getInt(KEY_USER_ID,  -1)

        if (currentUrl.isEmpty() || currentUid == -1) {
            Log.w(TAG, "sendLocation: missing credentials, skipping")
            return
        }

        val cleanBase = currentUrl.trimEnd('/')
        val apiBase   = if (cleanBase.endsWith("/api")) cleanBase else "$cleanBase/api"
        val endpoint  = "$apiBase/location/update"

        Log.d(TAG, "Sending → $endpoint  uid=$currentUid  lat=$lat  lng=$lng")

        val json = JSONObject().apply {
            put("user_id",   currentUid)
            put("latitude",  lat)
            put("longitude", lng)
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
                Log.d(TAG, "Location sent — HTTP ${response.code}")
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