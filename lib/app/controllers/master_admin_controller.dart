import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../data/api_service.dart';
import '../constants/api_endpoints.dart';

class MasterAdminController extends GetxController {
  final box = GetStorage();

  RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;
  RxBool loading       = false.obs;
  RxBool loadingCreate = false.obs;

  IO.Socket? socket;
  Timer? _refreshTimer;

  late RxBool geofenceAlertOn;
  late RxBool batteryAlertOn;

  // Bottom nav index
  RxInt navIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    geofenceAlertOn = RxBool(box.read("geo_alert") ?? true);
    batteryAlertOn  = RxBool(box.read("bat_alert")  ?? true);
    _initSocket();
    loadUsers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      allUsers.refresh();
    });
  }

  // ──────────────────────────────────────────────────────────────
  // SOCKET
  // ──────────────────────────────────────────────────────────────
  void _initSocket() {
    try {
      socket = IO.io(
        ApiEndpoints.socketBase,
        IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build(),
      );
      socket!.onConnect((_) => socket!.emit("join", {"role": "admin"}));
      socket!.on("location_update", (data) {
        if (data == null) return;
        final int uid = data["user_id"];
        final idx = allUsers.indexWhere((u) => u["id"] == uid);
        if (idx != -1) {
          allUsers[idx]["lat"]         = (data["latitude"]  as num).toDouble();
          allUsers[idx]["lng"]         = (data["longitude"] as num).toDouble();
          allUsers[idx]["battery"]     = data["battery"] ?? -1;
          allUsers[idx]["last_update"] = data["timestamp"] ?? "";
          allUsers.refresh();
        }
      });
      socket!.on("geofence_event", (data) {
        if (data == null || !geofenceAlertOn.value) return;
        Get.snackbar("Geofence Alert",
            "${data['username']} ${data['type'] == 'enter' ? 'entered' : 'exited'} ${data['name']}",
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 4));
      });
      socket!.on("battery_alert", (data) {
        if (data == null || !batteryAlertOn.value) return;
        final idx = allUsers.indexWhere((u) => u["id"] == data["user_id"]);
        if (idx != -1) { allUsers[idx]["battery"] = data["battery"]; allUsers.refresh(); }
        Get.snackbar("Low Battery",
            "User ID ${data['user_id']} → ${data['battery']}%",
            snackPosition: SnackPosition.TOP);
      });
      socket!.connect();
    } catch (e) { print("Master socket error: $e"); }
  }

  bool isUserOnline(int userId) {
    final u = allUsers.firstWhereOrNull((u) => u["id"] == userId);
    if (u == null) return false;
    final last = u["last_update"];
    if (last == null || last.toString().isEmpty) return false;
    try {
      return DateTime.now().toUtc()
          .difference(DateTime.parse(last).toUtc()).inSeconds <= 30;
    } catch (_) { return false; }
  }

  // ──────────────────────────────────────────────────────────────
  // LOAD USERS
  // ──────────────────────────────────────────────────────────────
  Future<void> loadUsers() async {
    loading.value = true;
    try {
      final res = await ApiService.get(ApiEndpoints.masterUsers);
      if (res == null || res["success"] != true) {
        loading.value = false;
        return;
      }
      final rawList = res["users"] as List? ?? [];
      allUsers.value = rawList.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
      await _mergeLiveData();
    } catch (e) { print("loadUsers error: $e"); }
    loading.value = false;
  }

  Future<void> _mergeLiveData() async {
    try {
      final res = await ApiService.get(ApiEndpoints.getEmployees);
      if (res == null) return;
      List live = res is List ? res : (res["employees"] ?? res["users"] ?? []);
      for (final l in live) {
        if (l == null) continue;
        final idx = allUsers.indexWhere((u) => u["id"] == l["id"]);
        if (idx != -1) {
          if (l["lat"]         != null) allUsers[idx]["lat"]         = l["lat"];
          if (l["lng"]         != null) allUsers[idx]["lng"]         = l["lng"];
          if (l["battery"]     != null) allUsers[idx]["battery"]     = l["battery"];
          if (l["last_update"] != null) allUsers[idx]["last_update"] = l["last_update"];
        }
      }
      allUsers.refresh();
    } catch (e) { print("_mergeLiveData error: $e"); }
  }

  // Filtered getters
  List<Map<String, dynamic>> get admins =>
      allUsers.where((u) => u["role"] == "admin").toList();
  List<Map<String, dynamic>> get employees =>
      allUsers.where((u) => u["role"] == "employee").toList();
  List<Map<String, dynamic>> get specialEmployees =>
      allUsers.where((u) => u["role"] == "special_employee").toList();

  // ──────────────────────────────────────────────────────────────
  // CREATE USER
  // ──────────────────────────────────────────────────────────────
  Future<void> createUser({
    required String username,
    required String password,
    required String role,
    String? workingHoursSlot,
  }) async {
    loadingCreate.value = true;
    try {
      final res = await ApiService.post(ApiEndpoints.masterCreateUser,
          {"username": username, "password": password, "role": role});
      if (res == null || res["success"] != true) {
        Get.snackbar("Error", res?["message"] ?? "Failed",
            snackPosition: SnackPosition.BOTTOM);
        loadingCreate.value = false;
        return;
      }
      final int? newId = res["user_id"] as int?;
      if (workingHoursSlot != null && workingHoursSlot.isNotEmpty && newId != null) {
        await setWorkingHours(userId: newId, slot: workingHoursSlot);
      }
      Get.back();
      await loadUsers();
      Get.snackbar("Created", "User \"$username\" created",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) { print("createUser error: $e"); }
    loadingCreate.value = false;
  }

  // ──────────────────────────────────────────────────────────────
  // DELETE USER
  // ──────────────────────────────────────────────────────────────
  Future<void> deleteUser(int id) async {
    try {
      final res = await ApiService.delete("${ApiEndpoints.masterDeleteUser}/$id");
      if (res != null && res["success"] == true) {
        allUsers.removeWhere((u) => u["id"] == id);
        Get.snackbar("Deleted", "User removed", snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar("Error", res?["message"] ?? "Failed",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) { print("deleteUser error: $e"); }
  }

  // ──────────────────────────────────────────────────────────────
  // WORKING HOURS  — once set, cannot be changed
  // ──────────────────────────────────────────────────────────────
  Future<void> setWorkingHours({required int userId, required String slot}) async {
    try {
      final res = await ApiService.post(ApiEndpoints.masterWorkingHours,
          {"user_id": userId, "slot": slot});
      if (res != null && res["success"] == true) {
        final idx = allUsers.indexWhere((u) => u["id"] == userId);
        if (idx != -1) {
          allUsers[idx]["working_hours_slot"] = slot;
          allUsers.refresh();
        }
        Get.snackbar("Saved", "Working hours saved (cannot be changed)",
            snackPosition: SnackPosition.BOTTOM);
      } else {
        // Backend returns error if already set
        Get.snackbar("Error", res?["message"] ?? "Failed",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) { print("setWorkingHours error: $e"); }
  }

  // ──────────────────────────────────────────────────────────────
  // CONTROL STATUS
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getControlStatus(int userId) async {
    try {
      final res = await ApiService.get("${ApiEndpoints.masterControlStatus}/$userId");
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) { print("getControlStatus error: $e"); }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // FORCE TRACKING  — only allowed within working hours
  // ──────────────────────────────────────────────────────────────
  Future<bool> forceTracking({required int userId, required bool enabled}) async {
    try {
      final res = await ApiService.post(ApiEndpoints.masterForceTracking,
          {"user_id": userId, "enabled": enabled});
      if (res != null && res["success"] == true) {
        Get.snackbar("Success", "Tracking force ${enabled ? 'ON' : 'OFF'}",
            snackPosition: SnackPosition.BOTTOM);
        return true;
      } else {
        Get.snackbar("Error", res?["message"] ?? "Failed — may be outside working hours",
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) { print("forceTracking error: $e"); return false; }
  }

  // ──────────────────────────────────────────────────────────────
  // FORCE RECORDING  — only allowed within working hours
  // ──────────────────────────────────────────────────────────────
  Future<bool> forceRecording({required int userId, required bool enabled}) async {
    try {
      final res = await ApiService.post(ApiEndpoints.masterForceRecording,
          {"user_id": userId, "enabled": enabled});
      if (res != null && res["success"] == true) {
        Get.snackbar("Success", "Recording force ${enabled ? 'ON' : 'OFF'}",
            snackPosition: SnackPosition.BOTTOM);
        return true;
      } else {
        Get.snackbar("Error", res?["message"] ?? "Failed — may be outside working hours",
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) { print("forceRecording error: $e"); return false; }
  }

  // ──────────────────────────────────────────────────────────────
  // RECORDINGS LIST  for a user
  // ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> loadRecordings(int userId) async {
    try {
      final res = await ApiService.get("${ApiEndpoints.baseUrl}/recording/list/$userId");
      if (res != null && res["success"] == true) {
        final list = res["recordings"] as List? ?? [];
        return list.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) { print("loadRecordings error: $e"); }
    return [];
  }

  void toggleGeofenceAlert(bool v) {
    geofenceAlertOn.value = v;
    box.write("geo_alert", v);
  }

  void toggleBatteryAlert(bool v) {
    batteryAlertOn.value = v;
    box.write("bat_alert", v);
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    try { socket?.disconnect(); socket?.dispose(); } catch (_) {}
    super.onClose();
  }
}