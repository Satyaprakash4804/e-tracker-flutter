// lib/app/services/background_service.dart
//
// Handles:
//  1. Background location permission (Android 10+ — separate from foreground)
//  2. Battery optimization exclusion (Doze mode exemption)
//  3. Starting the native Kotlin LocationService via MethodChannel
//  4. Flutter-side Timer loop for foreground location updates

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/api_service.dart';
import '../constants/api_endpoints.dart';

class BackgroundService {
  static const _platform = MethodChannel("etracker_channel");
  static final _battery  = Battery();

  static Timer? _timer;
  static int?   _userId;
  static bool   _running = false;
  static Duration interval = const Duration(seconds: 8);

  // ── START ──────────────────────────────────────────────────────
  static Future<void> start(int userId, {Duration? every}) async {
    if (_running) return;

    _userId = userId;
    if (every != null) interval = every;

    // Step 1: Foreground location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint("❌ Foreground location permission denied");
      return;
    }

    // Step 2: Background location permission (Android 10+ — MUST be separate)
    await _requestBackgroundLocation();

    // Step 3: Battery optimization exclusion (Doze mode)
    await _requestBatteryOptimizationExclusion();

    // Step 4: GPS enabled check
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint("❌ GPS is disabled");
      return;
    }

    // Step 5: Start native Kotlin foreground service
    _running = true;
    try {
      final serverBase =
          ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final token = GetStorage().read("token") ?? "";

      await _platform.invokeMethod("startService", {
        "user_id":   userId,
        "serverUrl": serverBase,
        "token":     token,
      });
      debugPrint("✅ Native service started → $serverBase");
    } catch (e) {
      debugPrint("⚠️ Start native service failed: $e");
      _running = false;
      return;
    }

    // Step 6: Flutter-side timer for live UI updates while foreground
    _timer?.cancel();
    await _sendLocation();
    _timer = Timer.periodic(interval, (_) async {
      if (!_running) return;
      await _sendLocation();
    });
  }

  // ── STOP ───────────────────────────────────────────────────────
  static Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;

    try {
      await _platform.invokeMethod("stopService");
      debugPrint("🛑 Native service stopped");
    } catch (_) {}
  }

  // ── BACKGROUND LOCATION PERMISSION ────────────────────────────
  // Android 10 (API 29)+ requires ACCESS_BACKGROUND_LOCATION as a
  // separate runtime permission. The user must choose "Allow all the
  // time" in system settings. This CANNOT be bundled with the
  // foreground location prompt — it must be a dedicated request.
  static Future<void> _requestBackgroundLocation() async {
    try {
      final status = await Permission.locationAlways.status;
      debugPrint("📍 Background location: $status");

      if (status.isGranted) return; // Already granted, nothing to do

      if (status.isPermanentlyDenied) {
        // Sent to app settings — user manually grants "Allow all the time"
        _showSettingsSnackbar(
          "Background location denied. Go to Settings → Location → Allow all the time.",
        );
        return;
      }

      // Show explanation dialog, then request
      final ok = await _confirmDialog(
        icon: Icons.location_on,
        iconColor: Colors.blue,
        title: "Background Location",
        message:
            "E-Tracker needs \"Allow all the time\" location access so tracking "
            "continues when the app is closed.\n\n"
            "On the next screen, please select: Allow all the time.",
        confirmLabel: "Continue",
        confirmColor: Colors.blue,
      );

      if (ok) {
        final result = await Permission.locationAlways.request();
        debugPrint("📍 Background location result: $result");
        if (result.isPermanentlyDenied) {
          await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint("⚠️ Background location error: $e");
    }
  }

  // ── BATTERY OPTIMIZATION EXCLUSION ────────────────────────────
  // Doze mode (Android 6+) and App Standby suspend background
  // processes including foreground services. Without this exclusion,
  // the service is paused within ~10 minutes on most devices.
  static Future<void> _requestBatteryOptimizationExclusion() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint("🔋 Battery optimization: $status");

      if (status.isGranted) return; // Already excluded

      final ok = await _confirmDialog(
        icon: Icons.battery_charging_full,
        iconColor: Colors.orange,
        title: "Battery Optimization",
        message:
            "To keep tracking running in the background, please allow "
            "E-Tracker to ignore battery optimization.\n\n"
            "Without this, your device will stop tracking after a few minutes.",
        confirmLabel: "Disable",
        confirmColor: Colors.orange,
      );

      if (ok) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint("⚠️ Battery optimization error: $e");
    }
  }

  // ── SHARED DIALOG HELPER ───────────────────────────────────────
  static Future<bool> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    bool result = false;
    final context = Get.context;
    if (context == null) return true; // No UI — proceed anyway

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message, style: const TextStyle(height: 1.55)),
        actions: [
          TextButton(
            onPressed: () { result = false; Get.back(); },
            child: Text("Skip",
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () { result = true; Get.back(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result;
  }

  static void _showSettingsSnackbar(String msg) {
    Get.snackbar(
      "Permission Required",
      msg,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.orange[100],
      colorText: Colors.orange[900],
      icon: const Icon(Icons.settings, color: Colors.orange),
      mainButton: TextButton(
        onPressed: () => openAppSettings(),
        child: const Text("Settings", style: TextStyle(color: Colors.orange)),
      ),
    );
  }

  // ── FLUTTER-SIDE LOCATION SEND ─────────────────────────────────
  // This runs while the app is in the foreground.
  // When the app is killed, the native Kotlin service handles sending.
  static Future<void> _sendLocation() async {
    if (!_running || _userId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final batteryLevel = await _battery.batteryLevel;
      await ApiService.post(ApiEndpoints.updateLocation, {
        "user_id":   _userId,
        "latitude":  pos.latitude,
        "longitude": pos.longitude,
        "battery":   batteryLevel,
      });
    } catch (e) {
      debugPrint("_sendLocation error: $e");
    }
  }
}