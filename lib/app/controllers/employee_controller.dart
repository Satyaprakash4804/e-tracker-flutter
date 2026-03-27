import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../constants/api_endpoints.dart';
import '../services/background_service.dart';
import '../data/api_service.dart';

class EmployeeController extends GetxController {
  // ============================
  // OBSERVABLE STATE
  // ============================
  RxList fences = [].obs;
  RxBool tracking = false.obs;
  RxBool loadingFences = false.obs;

  /// 🔋 Battery percentage
  RxInt battery = (-1).obs;

  RxString employeeName = "".obs;

  /// ✅ BACKEND TIME ONLY
  RxString lastUpdateTime = "".obs;

  /// Live movement (socket)
  RxDouble liveLat = 0.0.obs;
  RxDouble liveLng = 0.0.obs;

  int userId = 0;

  IO.Socket? socket;
  final box = GetStorage();
  Timer? _dbTimeTimer;

  // ============================
  // SET USER
  // ============================
  void setUser(int id, String name) {
    userId = id;
    employeeName.value = name;

    box.write("user_id", id);
    box.write("username", name);

    _initSocket();
    loadGeofences();
    _loadLatestLocationFromBackend();
  }

  String _formatBackendTime(String raw) {
    try {
      final utc = DateTime.parse(raw);
      final local = utc.toLocal();

      String two(int n) => n.toString().padLeft(2, '0');

      return "${two(local.day)}-${two(local.month)}-${local.year} "
          "${two(local.hour)}:${two(local.minute)}:${two(local.second)}";
    } catch (e) {
      return raw;
    }
  }

  // ============================
  // LOAD LATEST LOCATION (DB)
  // ============================
  Future<void> _loadLatestLocationFromBackend() async {
    if (userId == 0) return;

    final res = await ApiService.get("${ApiEndpoints.latestLocation}/$userId");

    if (res != null && res["success"] == true) {
      liveLat.value = (res["latitude"] as num).toDouble();
      liveLng.value = (res["longitude"] as num).toDouble();
      battery.value = res["battery"] ?? -1;
      lastUpdateTime.value = res["time"];
    }
  }

  // ============================
  // SOCKET CONNECTION
  // ============================
  void _initSocket() {
    if (socket != null) return;

    socket = IO.io(
      ApiEndpoints.socketBase,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket!.onConnect((_) {
      debugPrint("🟢 Employee socket connected");
      socket!.emit("join", {"user_id": userId});
    });

    socket!.on("location_update", (data) {
      if (data == null || data["user_id"] != userId) return;

      liveLat.value = (data["latitude"] as num).toDouble();
      liveLng.value = (data["longitude"] as num).toDouble();

      if (data["battery"] != null) {
        battery.value = data["battery"];
      }

      final t = data["time"] ?? data["timestamp"];
      if (t != null) {
        lastUpdateTime.value = _formatBackendTime(t);
      }
    });

    socket!.on("battery_alert", (data) {
      if (data == null || data["user_id"] != userId) return;

      Get.snackbar(
        "⚠️ Low Battery",
        "Battery is ${data['battery']}%",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red[900],
        icon: const Icon(Icons.battery_alert, color: Colors.red),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    });

    socket!.on("geofence_event", (data) {
      if (data == null || data["user_id"] != userId) return;

      final String geofenceName = data["name"] ?? "Unknown";
      final String type = data["type"];
      final String scope = data["scope"] ?? "employee";
      final bool isEnter = type == "enter";

      Get.snackbar(
        isEnter ? "🟢 Entered Geofence" : "🔴 Exited Geofence",
        "${scope == 'global' ? 'Global' : 'Employee'} Geofence: $geofenceName",
        backgroundColor:
            isEnter ? Colors.green.shade100 : Colors.orange.shade100,
        colorText: isEnter ? Colors.green[900] : Colors.orange[900],
        icon: Icon(
          isEnter ? Icons.location_on : Icons.location_off,
          color: isEnter ? Colors.green[700] : Colors.orange[700],
        ),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      loadGeofences();
    });

    socket!.onDisconnect((_) {
      debugPrint("🔴 Employee socket disconnected");
    });

    socket!.connect();
  }

  // ============================
  // DB TIME AUTO REFRESH
  // ============================
  void _startDbTimeRefresh() {
    _dbTimeTimer?.cancel();
    _dbTimeTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadLatestLocationFromBackend(),
    );
  }

  void _stopDbTimeRefresh() {
    _dbTimeTimer?.cancel();
    _dbTimeTimer = null;
  }

  // ============================
  // LOAD EMPLOYEE + GLOBAL GEOFENCES
  // ============================
  Future<void> loadGeofences() async {
    if (userId == 0) return;

    loadingFences.value = true;

    try {
      final empRes =
          await ApiService.get("${ApiEndpoints.listGeofence}/$userId");

      final globalRes = await ApiService.get(
        "${ApiEndpoints.globalEmployeeGeofences}/$userId",
      );

      List empFences = empRes is List ? empRes : [];
      List globalFences = globalRes is List ? globalRes : [];

      fences.value = [
        ...globalFences,
        ...empFences,
      ];
    } catch (e) {
      fences.clear();
      debugPrint("❌ Load geofences error: $e");
    }

    loadingFences.value = false;
  }

  // ============================
  // START / STOP TRACKING
  // ============================
  Future<void> startTracking() async {
    if (!await _ensureGpsPermission()) return;

    await BackgroundService.start(
      userId,
      every: const Duration(seconds: 8),
    );

    tracking.value = true;
    _startDbTimeRefresh();
  }

  Future<void> stopTracking() async {
    await BackgroundService.stop();
    tracking.value = false;
    _stopDbTimeRefresh();
    await _loadLatestLocationFromBackend();
  }

  // ============================
  // 📸 COMPRESS IMAGE HELPER
  // Returns compressed bytes with geo-stamp overlay
  // ============================
  Future<List<int>> _compressAndStamp({
    required String filePath,
    required double lat,
    required double lng,
    required int batteryLevel,
    int maxWidth = 1280,
    int quality = 75,
  }) async {
    final rawBytes = await File(filePath).readAsBytes();

    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) throw "Could not decode image";

    // ── Resize if wider than maxWidth ──────────────────────────────────────
    if (image.width > maxWidth) {
      image = img.copyResize(image, width: maxWidth);
    }

    // ── Black stamp box at bottom (20 % height) ───────────────────────────
    final int boxHeight = (image.height * 0.20).toInt();

    img.fillRect(
      image,
      x1: 0,
      y1: image.height - boxHeight,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgb8(0, 0, 0),
    );

    final String stampText =
        "Lat: $lat\n"
        "Lng: $lng\n"
        "Battery: $batteryLevel%\n"
        "Time: ${DateTime.now().toString().split('.').first}";

    img.drawString(
      image,
      stampText,
      font: img.arial48,
      x: 24,
      y: image.height - boxHeight + 24,
      color: img.ColorRgb8(255, 255, 255),
    );

    // ── Encode to JPEG ─────────────────────────────────────────────────────
    return img.encodeJpg(image, quality: quality);
  }

  // ============================
  // 📸 CAPTURE & UPLOAD PHOTO
  // ============================
  Future<void> captureAndUploadPhoto() async {
    if (!await _ensureGpsPermission()) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90, // pre-compress from camera
    );
    if (file == null) return;

    // ── Show loader ────────────────────────────────────────────────────────
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black54,
    );

    try {
      // 1️⃣ Get GPS position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 2️⃣ Get battery level
      final batteryLevel = await Battery().batteryLevel;

      // 3️⃣ Compress + stamp
      final compressedBytes = await _compressAndStamp(
        filePath: file.path,
        lat: pos.latitude,
        lng: pos.longitude,
        batteryLevel: batteryLevel,
        maxWidth: 1280,
        quality: 75,
      );

      debugPrint(
          "📦 Compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB");

      // 4️⃣ Save to temp file
      final dir = await getTemporaryDirectory();
      final outPath =
          "${dir.path}/geo_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final outFile = File(outPath);
      await outFile.writeAsBytes(compressedBytes);

      if (!await outFile.exists()) throw "Temp file not created";

      // 5️⃣ Build multipart request MANUALLY
      //    (avoids any ApiService Content-Type header bug)
      final uri = Uri.parse(ApiEndpoints.uploadPhoto);
      final request = http.MultipartRequest('POST', uri);

      // ── Auth header (copy token from your ApiService) ──────────────────
      final token = box.read("token");
      if (token != null && token.toString().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ── Fields ─────────────────────────────────────────────────────────
      request.fields['user_id'] = userId.toString();
      request.fields['username'] = employeeName.value;
      request.fields['latitude'] = pos.latitude.toString();
      request.fields['longitude'] = pos.longitude.toString();
      request.fields['battery'] = batteryLevel.toString();
      request.fields['description'] = 'Live upload';

      // ── File ───────────────────────────────────────────────────────────
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // must match backend field name
          outFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // 6️⃣ Send
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 Upload status: ${response.statusCode}");
      debugPrint("📡 Upload body:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _closeDialog();
        Get.snackbar(
          "✅ Success",
          "Geo-tagged photo uploaded successfully",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          duration: const Duration(seconds: 3),
        );
      } else {
        throw "Server error ${response.statusCode}: ${response.body}";
      }

      // 7️⃣ Clean up temp file
      try {
        await outFile.delete();
      } catch (_) {}
    } catch (e, stack) {
      debugPrint("❌ Upload error: $e");
      debugPrint("Stack: $stack");

      _closeDialog();

      Get.snackbar(
        "❌ Upload Failed",
        e.toString().length > 100
            ? "${e.toString().substring(0, 100)}…"
            : e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Safely closes the loader dialog
  void _closeDialog() {
    try {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    } catch (_) {}
  }

  // ============================
  // GPS & PERMISSIONS
  // ============================
  Future<bool> _ensureGpsPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showGpsDialog();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  void _showGpsDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text("Enable GPS"),
        content: const Text(
          "Please enable location services to continue.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              Get.back();
            },
            child: const Text("Open GPS"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // ============================
  // CLEANUP
  // ============================
  @override
  void onClose() {
    _dbTimeTimer?.cancel();
    socket?.disconnect();
    super.onClose();
  }
}