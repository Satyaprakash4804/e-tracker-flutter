package com.example.etracker_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import okhttp3.*
import org.json.JSONObject
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody

class LocationService : Service() {

    private lateinit var fusedClient: FusedLocationProviderClient
    private val http = OkHttpClient()

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        val uid = intent?.getIntExtra("user_id", -1) ?: -1
        val baseUrl = intent?.getStringExtra("serverUrl") ?: ""

        if (uid == -1 || baseUrl.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        // Save values globally
        FlutterBridge.userId = uid
        FlutterBridge.serverUrl = baseUrl

        // MUST show notification within 5 seconds of starting service
        startForegroundNotification()

        // Start GPS tracking
        startLocationUpdates()

        return START_STICKY
    }

    // -----------------------------
    // FOREGROUND NOTIFICATION
    // -----------------------------
    private fun startForegroundNotification() {

        val channelId = "etracker_location_channel"
        val channelName = "E-Tracker Background Location"

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel only for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            )
            chan.enableLights(false)
            chan.enableVibration(false)
            manager.createNotificationChannel(chan)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("E-Tracker is Running")
            .setContentText("Tracking your location in background…")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        // For Android 12+ use new flag
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                101,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(101, notification)
        }
    }

    // -----------------------------
    // LOCATION UPDATES
    // -----------------------------
    private fun startLocationUpdates() {

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            5000  // 5 sec interval
        )
            .setMinUpdateDistanceMeters(2f) // send update if moved 2 meters
            .build()

        fusedClient.requestLocationUpdates(
            request,
            callback,
            mainLooper
        )
    }

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location: Location = result.lastLocation ?: return
            sendLocationToServer(location.latitude, location.longitude)
        }
    }

    // -----------------------------
    // SEND TO BACKEND
    // -----------------------------
    private fun sendLocationToServer(lat: Double, lng: Double) {

        val json = JSONObject()
        json.put("user_id", FlutterBridge.userId)
        json.put("latitude", lat)
        json.put("longitude", lng)

        val body = json.toString()
            .toRequestBody("application/json".toMediaTypeOrNull())

        val request = Request.Builder()
            .url("${FlutterBridge.serverUrl}/location/update")
            .post(body)
            .build()

        http.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: java.io.IOException) {
                // optional: log failure
            }

            override fun onResponse(call: Call, response: Response) {
                response.close()
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedClient.removeLocationUpdates(callback)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
