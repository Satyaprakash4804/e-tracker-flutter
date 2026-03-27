import 'package:get/get.dart';
import '../data/api_service.dart';
import '../constants/api_endpoints.dart';

class GeofenceController extends GetxController {
  // -----------------------------
  // USER INPUT FIELDS
  // -----------------------------
  RxDouble latitude = 0.0.obs;     
  RxDouble longitude = 0.0.obs;    
  RxInt radius = 0.obs;
  RxString name = "".obs;

  // -----------------------------
  // DATA STORAGE
  // -----------------------------
  RxList fences = [].obs;
  RxBool loadingFences = false.obs;

  // =========================================================
  // LOAD GEOFENCES FOR EMPLOYEE
  // =========================================================
  Future<void> loadGeofences(int empId) async {
    loadingFences.value = true;

    try {
      final res = await ApiService.get("${ApiEndpoints.listGeofence}/$empId");

      if (res is List) {
        // backend returns a list directly
        fences.value = res;
      } else {
        print("❌ Unexpected response format: $res");
        fences.clear();
      }

    } catch (e) {
      print("❌ Error loading geofences: $e");
    }

    loadingFences.value = false;
  }

  // =========================================================
  // CREATE GEOFENCE
  // =========================================================
  Future<void> createGeofence(int empId) async {
    try {
      // ----------------------
      // INPUT VALIDATION
      // ----------------------
      if (name.value.isEmpty) {
        Get.snackbar("Error", "Enter geofence name");
        return;
      }

      if (latitude.value == 0 || longitude.value == 0) {
        Get.snackbar("Error", "Tap on map to select a location");
        return;
      }

      if (radius.value <= 0) {
        Get.snackbar("Error", "Radius must be greater than 0");
        return;
      }

      // ----------------------
      // REQUEST BODY
      // ----------------------
      final body = {
        "user_id": empId,
        "name": name.value,
        "latitude": latitude.value,
        "longitude": longitude.value,
        "radius": radius.value,
      };

      final res = await ApiService.post(ApiEndpoints.createGeofence, body);

      if (res != null && res["success"] == true) {
        Get.snackbar("Success", "Geofence created");

        // RESET INPUTS
        name.value = "";
        radius.value = 0;
        latitude.value = 0.0;
        longitude.value = 0.0;

      } else {
        Get.snackbar("Error", res?["message"] ?? "Failed to create geofence");
      }

    } catch (e) {
      print("❌ Error creating geofence: $e");
    }
  }

  // =========================================================
  // DELETE GEOFENCE
  // =========================================================
  Future<bool> deleteGeofence(int fenceId) async {
    try {
      final url = "${ApiEndpoints.deleteGeofence}/$fenceId";
      final res = await ApiService.delete(url);

      if (res != null && res["success"] == true) {

        // Auto-refresh list after deleting
        await Future.delayed(const Duration(milliseconds: 200));
        return true;

      } else {
        print("❌ Failed delete: ${res?["message"]}");
        return false;
      }

    } catch (e) {
      print("❌ Exception deleting geofence: $e");
      return false;
    }
  }
}
