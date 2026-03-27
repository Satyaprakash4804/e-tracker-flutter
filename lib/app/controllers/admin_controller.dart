import 'dart:async';

import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../data/api_service.dart';
import '../../constants/api_endpoints.dart';

class AdminController extends GetxController {
  // ============================
  // STATE
  // ============================
  RxList<Map<String, dynamic>> employees = <Map<String, dynamic>>[].obs;

  RxBool loading = false.obs;
  RxBool loadingCreate = false.obs;

  IO.Socket? socket;
  Timer? _onlineRefreshTimer;

  // ============================
  // INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    initSocket();
    loadEmployees();

    // 🔁 Force UI refresh every 10s to update online/offline
    _onlineRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) {
      employees.refresh();
    });
  }

  // ============================
  // SOCKET INITIALIZATION
  // ============================
  void initSocket() {
    socket = IO.io(
      ApiEndpoints.socketBase,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    // ----------------------------
    // CONNECT
    // ----------------------------
    socket!.onConnect((_) {
      print("🔌 Admin socket connected");

      // 🔑 JOIN ADMIN ROOM
      socket!.emit("join", {
        "role": "admin",
      });
    });

    socket!.onDisconnect((_) {
      print("❌ Admin socket disconnected");
    });

    // ------------------------------------------------
    // 🔴 LIVE LOCATION + BATTERY UPDATE
    // ------------------------------------------------
    socket!.on("location_update", (data) {
      if (data == null) return;

      final int uid = data["user_id"];
      final double lat = (data["latitude"] as num).toDouble();
      final double lng = (data["longitude"] as num).toDouble();
      final int battery = data["battery"] ?? -1;
      final String timestamp = data["timestamp"] ?? "";

      final index = employees.indexWhere((e) => e["id"] == uid);
      if (index != -1) {
        employees[index]["lat"] = lat;
        employees[index]["lng"] = lng;
        employees[index]["battery"] = battery;
        employees[index]["last_update"] = timestamp;
        employees.refresh();
      }
    });

    // ------------------------------------------------
    // 🔵 GEOFENCE ENTER / EXIT ALERT
    // ------------------------------------------------
    socket!.on("geofence_event", (data) {
      if (data == null) return;

      final String user =
          data["username"] ?? "Employee ${data['user_id']}";
      final String type = data["type"]; // enter / exit
      final String name = data["name"];
      final String scope = data["scope"] ?? "employee";

      Get.snackbar(
        "Geofence Alert",
        "$user ${type == 'enter' ? 'entered' : 'exited'} "
        "${scope == 'global' ? 'Global' : 'Employee'} Geofence: $name",
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    });

    // ------------------------------------------------
    // 🔋 LOW BATTERY ALERT (<25%)
    // ------------------------------------------------
    socket!.on("battery_alert", (data) {
      if (data == null) return;

      final int uid = data["user_id"];
      final int battery = data["battery"];

      Get.snackbar(
        "Low Battery Alert",
        "Employee ID $uid → Battery $battery%",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
        duration: const Duration(seconds: 5),
      );

      final index = employees.indexWhere((e) => e["id"] == uid);
      if (index != -1) {
        employees[index]["battery"] = battery;
        employees.refresh();
      }
    });

    socket!.connect();
  }

  // ============================
  // ONLINE / OFFLINE CHECK (🔥 IMPORTANT)
  // ============================
  bool isEmployeeOnline(int empId) {
    final emp = employees.firstWhereOrNull((e) => e["id"] == empId);
    if (emp == null) return false;
  
    final last = emp["last_update"];
    if (last == null || last.toString().isEmpty) return false;
  
    try {
      final lastTime = DateTime.parse(last).toUtc();
      final now = DateTime.now().toUtc();
      return now.difference(lastTime).inSeconds <= 30;
    } catch (e) {
      print("Online parse error: $e");
      return false;
    }
  }
  

  // ============================
  // LOAD EMPLOYEES
  // ============================
  Future<void> loadEmployees() async {
    loading.value = true;

    try {
      final res = await ApiService.get(ApiEndpoints.getEmployees);

      if (res == null) {
        loading.value = false;
        return;
      }

      if (res is List) {
        employees.value = List<Map<String, dynamic>>.from(res);
      } else if (res is Map && res.containsKey("employees")) {
        employees.value =
            List<Map<String, dynamic>>.from(res["employees"]);
      }
    } catch (e) {
      print("❌ ERROR loadEmployees: $e");
    }

    loading.value = false;
  }

  // ============================
  // CREATE EMPLOYEE
  // ============================
  Future<void> createEmployee(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      Get.snackbar("Error", "Username and password are required");
      return;
    }

    loadingCreate.value = true;

    try {
      final res = await ApiService.post(
        ApiEndpoints.createEmployee,
        {
          "username": username,
          "password": password,
        },
      );

      if (res != null && res["success"] == true) {
        Get.back();
        await loadEmployees();
        Get.snackbar("Success", "Employee created successfully");
      } else {
        Get.snackbar(
          "Error",
          res?["message"] ?? "Failed to create employee",
        );
      }
    } catch (e) {
      print("❌ ERROR createEmployee: $e");
      Get.snackbar("Error", "Failed to create employee");
    }

    loadingCreate.value = false;
  }

  // ============================
  // DELETE EMPLOYEE
  // ============================
  Future<void> deleteEmployee(int id) async {
    final url = "${ApiEndpoints.baseUrl}/admin/employee/$id";

    try {
      final res = await ApiService.delete(url);

      if (res != null && res["success"] == true) {
        await loadEmployees();
        Get.snackbar("Success", "Employee deleted");
      } else {
        Get.snackbar(
          "Error",
          res?["message"] ?? "Delete failed",
        );
      }
    } catch (e) {
      print("❌ ERROR deleteEmployee: $e");
      Get.snackbar("Error", "Failed to delete employee");
    }
  }

  // ============================
  // CLEANUP
  // ============================
  @override
  void onClose() {
    _onlineRefreshTimer?.cancel();
    socket?.disconnect();
    socket?.dispose();
    super.onClose();
  }
}
