// lib/app/services/background_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../data/api_service.dart';
import '../../constants/api_endpoints.dart';

class BackgroundService {
  static const platform = MethodChannel("etracker_channel");
  static final Battery _battery = Battery();

  static Timer? _timer;
  static int? _userId;
  static bool _running = false;
  static Duration interval = const Duration(seconds: 8);

  // --------------------------------------------------------
  // START BACKGROUND LOCATION SERVICE
  // --------------------------------------------------------
  static Future<void> start(int userId, {Duration? every}) async {
    if (_running) return;

    _running = true;
    _userId = userId;

    if (every != null) interval = every;

    // ✅ PERMISSION CHECK
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _running = false;
      return;
    }

    // ✅ GPS CHECK
    if (!await Geolocator.isLocationServiceEnabled()) {
      _running = false;
      return;
    }

    // ✅ START ANDROID FOREGROUND SERVICE
    try {
      final String serverBase =
          ApiEndpoints.baseUrl.replaceAll("/api", "");

      await platform.invokeMethod("startService", {
        "user_id": userId,
        "serverUrl": serverBase,
      });
    } catch (e) {
      _running = false;
      return;
    }

    // CANCEL OLD TIMER
    _timer?.cancel();

    // SEND FIRST LOCATION
    await _sendLocation();

    // START LOOP
    _timer = Timer.periodic(interval, (_) async {
      if (!_running) return;
      await _sendLocation();
    });
  }

  // --------------------------------------------------------
  // STOP BACKGROUND SERVICE
  // --------------------------------------------------------
  static Future<void> stop() async {
    _running = false;

    _timer?.cancel();
    _timer = null;

    try {
      await platform.invokeMethod("stopService");
    } catch (_) {}
  }

  // --------------------------------------------------------
  // SEND LOCATION TO BACKEND
  // --------------------------------------------------------
  static Future<void> _sendLocation() async {
    if (!_running || _userId == null) return;

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      int batteryLevel = await _battery.batteryLevel;

      final body = {
        "user_id": _userId,
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "battery": batteryLevel,

        
      };

      await ApiService.post(ApiEndpoints.updateLocation, body);
    } catch (_) {}
  }
}
