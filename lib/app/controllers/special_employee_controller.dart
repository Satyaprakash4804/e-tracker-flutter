import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../data/api_service.dart';
import '../constants/api_endpoints.dart';
import 'employee_controller.dart';

class SpecialEmployeeController extends GetxController {
  final box      = GetStorage();
  final _battery = Battery();
  AudioRecorder? _recorder;

  late int    userId;
  late String username;

  // ── UI State ──
  RxBool  loading       = false.obs;
  // Online = only true when location is actively being sent within last 30s
  RxBool  isOnline      = false.obs;
  RxBool  trackingOn    = false.obs;
  RxBool  recordingOn   = false.obs;
  RxBool  trackLocked   = false.obs;
  RxBool  recLocked     = false.obs;

  // ── Location ──
  Rx<double?> lat      = Rx<double?>(null);
  Rx<double?> lng      = Rx<double?>(null);
  RxString lastUpdate  = ''.obs;
  RxInt    battery     = (-1).obs;

  // ── Shift / Geofences / Notifications ──
  RxString workingSlot = ''.obs;
  RxList<Map<String, dynamic>> geofences     = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  // ── Profile selfie ──
  RxString selfieUrl = ''.obs;

  // ── Recording internals ──
  bool      _isRecording = false;
  DateTime? _recStart;

  // ── Online: only true when actively tracking + sending location ──
  // Socket connect alone does NOT make user online
  DateTime? _lastLocationSent;
  Timer?    _onlineCheckTimer;

  IO.Socket? socket;
  Timer?     _locationTimer;
  Timer?     _batteryTimer;

  @override
  void onInit() {
    super.onInit();
    userId   = box.read("user_id")  ?? 0;
    username = box.read("username") ?? "";

    _initSocket();
    _startBatteryMonitor();
    _startOnlineCheck();
    loadProfile();
    loadControlStatus();
    loadLatestLocation();
    loadGeofences();
    _ensureEmployeeController();
  }

  void _ensureEmployeeController() {
    if (!Get.isRegistered<EmployeeController>()) Get.put(EmployeeController());
    final emp = Get.find<EmployeeController>();
    emp.setUser(userId, username);
    ever(lat,        (v) { if (v != null) emp.liveLat.value = v; });
    ever(lng,        (v) { if (v != null) emp.liveLng.value = v; });
    ever(battery,    (v) { emp.battery.value = v; });
    ever(lastUpdate, (v) { emp.lastUpdateTime.value = v; });
    ever(geofences,  (_) {
      emp.fences.value = geofences.map((f) => Map<String, dynamic>.from(f)).toList();
    });
  }

  Future<void> loadProfile() async {
    try {
      final res = await ApiService.get("${ApiEndpoints.employeeProfile}/$userId");
      if (res != null && res["success"] == true) {
        final data = res["data"] as Map?;
        final path = data?["selfie_path"] as String? ?? "";
        if (path.isNotEmpty) {
          final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api$'), '');
          selfieUrl.value = path.startsWith("http") ? path : "$base$path";
        }
      }
    } catch (e) { debugPrint("loadProfile error: $e"); }
  }

  // ── Socket — connect does NOT set online ──────────────────────
  void _initSocket() {
    try {
      socket = IO.io(ApiEndpoints.socketBase,
          IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build());

      socket!.onConnect((_) {
        // Don't set isOnline here — only set when location is actually sent
        socket!.emit("join", {"user_id": userId});
      });

      socket!.onDisconnect((_) {
        // On disconnect → offline immediately
        isOnline.value = false;
        _lastLocationSent = null;
      });

      socket!.on("battery_alert", (data) {
        if (data == null || data["user_id"] != userId) return;
        _addNotif("battery", "⚠️ Low Battery: ${data['battery']}%");
      });

      socket!.on("geofence_event", (data) {
        if (data == null || data["user_id"] != userId) return;
        _addNotif(data["type"] == "enter" ? "enter" : "exit",
            "${data['type'] == 'enter' ? 'Entered' : 'Exited'}: ${data['name']}");
        loadGeofences();
      });

      socket!.connect();
    } catch (e) { debugPrint("Socket error: $e"); }
  }

  // Online only when a location was successfully sent within last 30s
  void _markLocationSent() {
    _lastLocationSent = DateTime.now();
    isOnline.value = true;
  }

  void _startOnlineCheck() {
    _onlineCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_lastLocationSent == null) {
        isOnline.value = false;
        return;
      }
      final elapsed = DateTime.now().difference(_lastLocationSent!).inSeconds;
      // Online only if sent location within last 20s (2 GPS cycles)
      isOnline.value = elapsed <= 20;
    });
  }

  void _addNotif(String type, String msg) {
    notifications.insert(0, {
      "type": type, "msg": msg,
      "time": DateTime.now().toLocal().toString().substring(11, 16),
    });
    if (notifications.length > 50) notifications.removeLast();
  }

  // ── Battery ──────────────────────────────────────────────────
  void _startBatteryMonitor() {
    _readBattery();
    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (_) => _readBattery());
  }
  Future<void> _readBattery() async {
    try { battery.value = await _battery.batteryLevel; }
    catch (e) { debugPrint("Battery error: $e"); }
  }

  // ── Control Status ───────────────────────────────────────────
  Future<void> loadControlStatus() async {
    loading.value = true;
    try {
      final res = await ApiService.get(
          "${ApiEndpoints.specialControlStatus}/$userId");
      if (res == null || res["success"] != true) {
        loading.value = false;
        return;
      }
      final ts = res["tracking"]  as Map? ?? {};
      final rs = res["recording"] as Map? ?? {};

      trackLocked.value = ts["master_force"] == true || ts["master_force"] == 1;
      trackingOn.value  = ts["effective"]    == true || ts["effective"]    == 1;
      recLocked.value   = rs["master_force"] == true || rs["master_force"] == 1;
      recordingOn.value = rs["effective"]    == true || rs["effective"]    == 1;
      workingSlot.value = res["working_hours_slot"] ?? '';

      if (trackingOn.value && _locationTimer == null) _startGPS();
      else if (!trackingOn.value) _stopGPS();

      if (recordingOn.value && !_isRecording) await _startAudioRecording();
      else if (!recordingOn.value && _isRecording) await _stopAndUploadRecording();

      if (Get.isRegistered<EmployeeController>()) {
        Get.find<EmployeeController>().tracking.value = trackingOn.value;
      }
    } catch (e) { debugPrint("loadControlStatus error: $e"); }
    loading.value = false;
  }

  Future<void> toggleTracking() async {
    if (trackLocked.value && trackingOn.value) {
      Get.snackbar("Locked", "Admin force-enabled. Cannot turn off.",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final ns = !trackingOn.value;
    final res = await ApiService.post(
        ApiEndpoints.specialToggleTracking, {"user_id": userId, "enabled": ns});
    if (res != null && res["success"] == true) {
      trackingOn.value = ns;
      if (ns) _startGPS(); else { _stopGPS(); isOnline.value = false; _lastLocationSent = null; }
      if (Get.isRegistered<EmployeeController>()) {
        Get.find<EmployeeController>().tracking.value = ns;
      }
      Get.snackbar(ns ? "Tracking ON" : "Tracking OFF",
          ns ? "Location sharing started" : "Stopped",
          snackPosition: SnackPosition.BOTTOM);
    } else if (res != null && res["locked"] == true) {
      trackingOn.value = true;
      Get.snackbar("Locked", "Admin locked tracking ON.",
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar("Error", res?["message"] ?? "Failed",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> toggleRecording(bool val) async {
    if (recLocked.value && !val) {
      recordingOn.value = true;
      Get.snackbar("Locked", "Admin force-enabled. Cannot turn off.",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final res = await ApiService.post(
        ApiEndpoints.specialToggleRecording, {"user_id": userId, "enabled": val});
    if (res != null && res["success"] == true) {
      recordingOn.value = val;
      if (val) await _startAudioRecording();
      else await _stopAndUploadRecording();
    } else if (res != null && res["locked"] == true) {
      recordingOn.value = true;
      Get.snackbar("Locked", "Admin locked recording ON.",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _startAudioRecording() async {
    if (_isRecording) return;
    try {
      _recorder = AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        _recorder!.dispose(); _recorder = null;
        Get.snackbar("Permission", "Microphone permission required.",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/rec_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a";
      _recStart = DateTime.now().toUtc();
      await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: path);
      _isRecording = true;
      debugPrint("🎙 Recording started");
    } catch (e) {
      debugPrint("_startAudioRecording error: $e");
      try { _recorder?.dispose(); } catch (_) {}
      _recorder = null; _isRecording = false; _recStart = null;
    }
  }

  Future<void> _stopAndUploadRecording() async {
    if (!_isRecording || _recorder == null) return;
    try {
      final path    = await _recorder!.stop();
      final endTime = DateTime.now().toUtc();
      _isRecording  = false;
      try { _recorder!.dispose(); } catch (_) {}
      _recorder = null;
      if (path != null && _recStart != null) {
        await _uploadRecording(filePath: path, startedAt: _recStart!, endedAt: endTime);
      }
      _recStart = null;
    } catch (e) {
      debugPrint("_stopAndUploadRecording error: $e");
      _isRecording = false;
      try { _recorder?.dispose(); } catch (_) {}
      _recorder = null;
    }
  }

  Future<void> _uploadRecording({
    required String filePath,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      final uri = Uri.parse("${ApiEndpoints.baseUrl}/recording/save");
      final req = http.MultipartRequest("POST", uri);
      final token = box.read("token") ?? "";
      if (token.isNotEmpty) req.headers["Authorization"] = "Bearer $token";
      req.fields["user_id"]    = userId.toString();
      req.fields["started_at"] = startedAt.toIso8601String();
      req.fields["ended_at"]   = endedAt.toIso8601String();
      req.files.add(await http.MultipartFile.fromPath("audio", filePath));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      debugPrint("📤 Upload ${streamed.statusCode}: $body");
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        try { await file.delete(); } catch (_) {}
      }
    } catch (e) { debugPrint("_uploadRecording error: $e"); }
  }

  // ── GPS Loop ─────────────────────────────────────────────────
  void _startGPS() {
    if (_locationTimer != null) return;
    _sendLocation();
    _locationTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _sendLocation());
  }

  void _stopGPS() {
    _locationTimer?.cancel();
    _locationTimer = null;
    isOnline.value = false;
    _lastLocationSent = null;
  }

  Future<void> _sendLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      lat.value        = pos.latitude;
      lng.value        = pos.longitude;
      lastUpdate.value = DateTime.now().toIso8601String();

      await _readBattery();

      await ApiService.post(ApiEndpoints.updateLocation, {
        "user_id": userId, "latitude": pos.latitude,
        "longitude": pos.longitude, "battery": battery.value,
      });

      // Only mark online AFTER successful location send
      _markLocationSent();
    } catch (e) {
      debugPrint("_sendLocation error: $e");
    }
  }

  Future<void> loadLatestLocation() async {
    try {
      final res = await ApiService.get("${ApiEndpoints.latestLocation}/$userId");
      if (res != null && res["success"] == true) {
        lat.value        = (res["latitude"]  as num?)?.toDouble();
        lng.value        = (res["longitude"] as num?)?.toDouble();
        lastUpdate.value = res["time"] ?? '';
        if (Get.isRegistered<EmployeeController>()) {
          final emp = Get.find<EmployeeController>();
          if (lat.value != null) emp.liveLat.value = lat.value!;
          if (lng.value != null) emp.liveLng.value = lng.value!;
          emp.lastUpdateTime.value = lastUpdate.value;
        }
      }
    } catch (e) { debugPrint("loadLatestLocation error: $e"); }
  }

  Future<void> loadGeofences() async {
    try {
      final results = await Future.wait([
        ApiService.get("${ApiEndpoints.listGeofence}/$userId"),
        ApiService.get("${ApiEndpoints.globalEmployeeGeofences}/$userId"),
      ]);
      final all = <Map<String, dynamic>>[];
      for (final res in results) {
        if (res == null) continue;
        final List raw = res is List ? res
            : (res is Map ? (res["geofences"] ?? res["data"] ?? []) : []);
        all.addAll(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      }
      if (lat.value != null && lng.value != null) {
        for (final g in all) {
          g["_distance"] = _haversine(lat.value!, lng.value!,
              (g["latitude"]  as num?)?.toDouble() ?? 0,
              (g["longitude"] as num?)?.toDouble() ?? 0);
        }
      }
      geofences.value = all;
      if (Get.isRegistered<EmployeeController>()) {
        Get.find<EmployeeController>().fences.value =
            all.map((f) => Map<String, dynamic>.from(f)).toList();
      }
    } catch (e) { debugPrint("loadGeofences error: $e"); }
  }

  // ================================================================
  // GEO-TAGGED PHOTO — fixed: proper dialog management
  // ================================================================
  Future<void> captureAndUploadPhoto() async {
    if (!await _ensureGpsPermission()) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 90);
    if (file == null) return;

    // Show loading dialog
    bool dialogOpen = false;
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Uploading photo..."),
            ]),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    dialogOpen = true;

    void closeDialog() {
      if (dialogOpen) {
        dialogOpen = false;
        try { if (Get.isDialogOpen == true) Get.back(); } catch (_) {}
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      final batteryLevel = await Battery().batteryLevel;

      final compressedBytes = await _compressAndStamp(
          filePath: file.path, lat: pos.latitude,
          lng: pos.longitude, batteryLevel: batteryLevel);

      final dir = await getTemporaryDirectory();
      final outPath = "${dir.path}/geo_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final outFile = File(outPath);
      await outFile.writeAsBytes(compressedBytes);
      if (!await outFile.exists()) throw Exception("Temp file not created");

      final uri = Uri.parse(ApiEndpoints.uploadPhoto);
      final request = http.MultipartRequest('POST', uri);
      final token = box.read("token");
      if (token != null && token.toString().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['user_id']     = userId.toString();
      request.fields['username']    = username;
      request.fields['latitude']    = pos.latitude.toString();
      request.fields['longitude']   = pos.longitude.toString();
      request.fields['battery']     = batteryLevel.toString();
      request.fields['description'] = 'Live upload';
      request.files.add(await http.MultipartFile.fromPath(
          'image', outFile.path, contentType: MediaType('image', 'jpeg')));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      closeDialog();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar("✅ Success", "Geo-tagged photo uploaded",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900]);
      } else {
        throw Exception("Server error ${response.statusCode}");
      }
      try { await outFile.delete(); } catch (_) {}
    } catch (e) {
      closeDialog();
      Get.snackbar("❌ Upload Failed",
          e.toString().length > 80
              ? "${e.toString().substring(0, 80)}…"
              : e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900]);
    }
  }

  Future<List<int>> _compressAndStamp({
    required String filePath, required double lat,
    required double lng, required int batteryLevel,
    int maxWidth = 1280, int quality = 75,
  }) async {
    final rawBytes = await File(filePath).readAsBytes();
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) throw Exception("Could not decode image");
    if (image.width > maxWidth) image = img.copyResize(image, width: maxWidth);
    final int boxH = (image.height * 0.20).toInt();
    img.fillRect(image, x1: 0, y1: image.height - boxH,
        x2: image.width, y2: image.height, color: img.ColorRgb8(0, 0, 0));
    img.drawString(image,
        "Lat: $lat\nLng: $lng\nBattery: $batteryLevel%\n"
        "Time: ${DateTime.now().toString().split('.').first}",
        font: img.arial48, x: 24, y: image.height - boxH + 24,
        color: img.ColorRgb8(255, 255, 255));
    return img.encodeJpg(image, quality: quality);
  }

  Future<bool> _ensureGpsPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      Get.dialog(AlertDialog(
        title: const Text("Enable GPS"),
        content: const Text("Please enable location services."),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                Get.back();
                await Geolocator.openLocationSettings();
              },
              child: const Text("Open GPS")),
        ],
      ));
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  // ── Helpers ──────────────────────────────────────────────────
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String formatDistance(double m) =>
      m >= 1000 ? "${(m / 1000).toStringAsFixed(2)} km" : "${m.round()} m";

  String slotLabel(String? slot) => const {
    '9-5': '09:00 – 17:00  Day Shift',
    '5-1': '17:00 – 01:00  Evening',
    '1-9': '01:00 – 09:00  Night Shift',
  }[slot] ?? 'Not Assigned';

  String formatTime(String? ts) {
    if (ts == null || ts.isEmpty) return "Never";
    try {
      final dt = DateTime.parse(ts).toLocal();
      return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}  "
          "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}";
    } catch (_) { return ts; }
  }

  void logout() {
    _stopGPS();
    _batteryTimer?.cancel();
    _onlineCheckTimer?.cancel();
    if (_isRecording) _stopAndUploadRecording();
    try { socket?.disconnect(); socket?.dispose(); } catch (_) {}
    box.erase();
    Get.offAllNamed('/login');
  }

  @override
  void onClose() {
    _stopGPS();
    _batteryTimer?.cancel();
    _onlineCheckTimer?.cancel();
    if (_isRecording) _stopAndUploadRecording();
    try { _recorder?.dispose(); } catch (_) {}
    try { socket?.disconnect(); socket?.dispose(); } catch (_) {}
    super.onClose();
  }
}