import 'package:get/get.dart';
import '../data/api_service.dart';
import '../constants/api_endpoints.dart';

class GlobalGeofenceController extends GetxController {
  // =====================================================
  // FORM INPUTS
  // =====================================================
  RxString name = "".obs;
  RxDouble latitude = 0.0.obs;
  RxDouble longitude = 0.0.obs;
  RxInt radius = 0.obs;

  /// Assign mode
  RxBool assignAll = true.obs;
  RxList<int> selectedEmployeeIds = <int>[].obs;

  // =====================================================
  // DATA
  // =====================================================
  RxList<Map<String, dynamic>> globalFences =
      <Map<String, dynamic>>[].obs;

  RxBool loading = false.obs;
  RxBool creating = false.obs;

  // =====================================================
  // LOAD ALL GLOBAL GEOFENCES (ADMIN)
  // =====================================================
  Future<void> loadGlobalGeofences() async {
    loading.value = true;

    try {
      final res =
          await ApiService.get(ApiEndpoints.listGlobalGeofences);

      if (res != null && res["success"] == true) {
        globalFences.value =
            List<Map<String, dynamic>>.from(res["geofences"]);
      } else {
        globalFences.clear();
        print("❌ Invalid response: $res");
      }
    } catch (e) {
      print("❌ Error loading global geofences: $e");
      globalFences.clear();
    }

    loading.value = false;
  }

  // =====================================================
  // CREATE GLOBAL GEOFENCE
  // =====================================================
  Future<void> createGlobalGeofence() async {
    if (creating.value) return;

    // ---------------- VALIDATION ----------------
    if (name.value.trim().isEmpty) {
      Get.snackbar("Error", "Enter geofence name");
      return;
    }

    if (latitude.value == 0 || longitude.value == 0) {
      Get.snackbar("Error", "Select location on map");
      return;
    }

    if (radius.value <= 0) {
      Get.snackbar("Error", "Radius must be greater than 0");
      return;
    }

    if (!assignAll.value && selectedEmployeeIds.isEmpty) {
      Get.snackbar("Error", "Select at least one employee");
      return;
    }

    creating.value = true;

    try {
      final body = {
        "name": name.value.trim(),
        "latitude": latitude.value,
        "longitude": longitude.value,
        "radius": radius.value,
        "assign_all": assignAll.value,
        "user_ids": selectedEmployeeIds,
      };

      final res = await ApiService.post(
        ApiEndpoints.createGlobalGeofence,
        body,
      );

      if (res != null && res["success"] == true) {
        Get.snackbar("Success", "Global geofence created");
        resetForm();
        await loadGlobalGeofences();
      } else {
        Get.snackbar(
          "Error",
          res?["message"] ?? "Failed to create global geofence",
        );
      }
    } catch (e) {
      print("❌ Create global geofence error: $e");
      Get.snackbar("Error", "Failed to create geofence");
    }

    creating.value = false;
  }

  // =====================================================
  // DELETE GLOBAL GEOFENCE
  // =====================================================
  Future<void> deleteGlobalGeofence(int geofenceId) async {
    try {
      final res = await ApiService.delete(
        "${ApiEndpoints.deleteGlobalGeofence}/$geofenceId",
      );

      if (res != null && res["success"] == true) {
        globalFences.removeWhere((g) => g["id"] == geofenceId);
        Get.snackbar("Deleted", "Global geofence removed");
      } else {
        Get.snackbar("Error", "Failed to delete geofence");
      }
    } catch (e) {
      print("❌ Delete global geofence error: $e");
      Get.snackbar("Error", "Failed to delete geofence");
    }
  }

  // =====================================================
  // LOAD GLOBAL GEOFENCE EVENTS (ADMIN)
  // =====================================================
  Future<List<Map<String, dynamic>>> loadGlobalGeofenceEvents(
      int geofenceId) async {
    try {
      final res =
          await ApiService.get(ApiEndpoints.globalGeofenceEvents);

      if (res != null && res["success"] == true) {
        final events =
            List<Map<String, dynamic>>.from(res["events"]);

        // Filter events for selected geofence
        return events
            .where((e) => e["geofence_id"] == geofenceId)
            .toList();
      }
    } catch (e) {
      print("❌ Error loading global geofence events: $e");
    }

    return [];
  }

  // =====================================================
  // MAP HELPERS
  // =====================================================
  void setLatLng(double lat, double lng) {
    latitude.value = lat;
    longitude.value = lng;
  }

  // =====================================================
  // RESET FORM
  // =====================================================
  void resetForm() {
    name.value = "";
    radius.value = 0;
    latitude.value = 0.0;
    longitude.value = 0.0;
    assignAll.value = true;
    selectedEmployeeIds.clear();
  }
}
