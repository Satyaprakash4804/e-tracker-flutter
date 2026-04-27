import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../routes/app_routes.dart';
import '../data/api_service.dart';
import '../constants/api_endpoints.dart';
import '../controllers/employee_controller.dart';
import '../controllers/master_admin_controller.dart';
import '../controllers/special_employee_controller.dart';
import '../controllers/admin_controller.dart';

class LoginController extends GetxController {
  RxBool loading = false.obs;
  RxBool obscurePassword = true.obs;
  RxString errorMessage = ''.obs;

  final username = ''.obs;
  final password = ''.obs;

  final box = GetStorage();

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void clearError() {
    if (errorMessage.value.isNotEmpty) errorMessage.value = '';
  }

  // ── Helper: resolve registration status ──────────────────────
  // FIX: The root cause of the endless registration loop.
  //
  // Problem: login response may not include "registration_completed"
  // (older backend or field missing). When it's null, the old code
  // wrote employee_registered=false, overwriting the true that was
  // correctly saved after the employee completed registration.
  //
  // Solution:
  //  1. admin/master_admin are always registered — skip the check.
  //  2. If the API response contains registration_completed, trust it.
  //  3. If the field is missing from the response, call the dedicated
  //     registration-status endpoint to get the real value.
  //  4. NEVER write false if the storage already says true — once
  //     registered, never regress.
  Future<bool> _resolveRegistration({
    required String role,
    required int userId,
    required dynamic loginResponse,
  }) async {
    // admins are always registered — no registration page needed
    if (role == 'master_admin' || role == 'admin') {
      box.write("employee_registered", true);
      return true;
    }

    // Check if already registered in local storage (set after registration page submit)
    final bool alreadyInStorage = box.read("employee_registered") == true;
    if (alreadyInStorage) {
      // Already registered locally — trust it, don't regress
      return true;
    }

    // Try to read from login response first
    final dynamic fromResponse = loginResponse["registration_completed"];
    if (fromResponse != null) {
      final bool registered = fromResponse == true;
      box.write("employee_registered", registered);
      return registered;
    }

    // Field missing from response — call dedicated endpoint
    // This handles older backends that don't return registration_completed
    try {
      final res = await ApiService.get(
          "${ApiEndpoints.employeeRegistrationStatus}/$userId");
      final bool registered = res != null && res["registered"] == true;
      box.write("employee_registered", registered);
      return registered;
    } catch (_) {
      // Network error — assume not registered to be safe
      return false;
    }
  }

  // ============================
  // AUTO LOGIN (called from main.dart on app start)
  // ============================
  Future<void> tryAutoLogin() async {
    final bool loggedIn = box.read("logged_in") ?? false;
    if (!loggedIn) {
      Get.offAllNamed(Routes.LOGIN);
      return;
    }

    final String? role   = box.read("role");
    final int?    userId = box.read("user_id");
    final String? token  = box.read("token");
    final String? uname  = box.read("username");

    if (role == null || userId == null || token == null) {
      box.erase();
      Get.offAllNamed(Routes.LOGIN);
      return;
    }

    switch (role) {
      case "master_admin":
        Get.put(MasterAdminController());
        Get.offAllNamed(Routes.MASTER_ADMIN_DASHBOARD);
        break;

      case "admin":
        Get.put(AdminController());
        Get.offAllNamed(Routes.ADMIN_DASHBOARD);
        break;

      case "special_employee":
        if (!Get.isRegistered<SpecialEmployeeController>()) {
          Get.put(SpecialEmployeeController());
        }
        // FIX: Read from storage — never call API during auto-login
        // because user is already logged in and the value was set correctly.
        final bool registered = box.read("employee_registered") == true;
        if (!registered) {
          box.write("post_registration_route", Routes.SPECIAL_EMPLOYEE_DASHBOARD);
          Get.offAllNamed(Routes.EMPLOYEE_REGISTRATION);
        } else {
          Get.offAllNamed(Routes.SPECIAL_EMPLOYEE_DASHBOARD);
        }
        break;

      case "employee":
        final emp = Get.isRegistered<EmployeeController>()
            ? Get.find<EmployeeController>()
            : Get.put(EmployeeController());
        emp.setUser(userId, uname ?? "");
        final bool registered = box.read("employee_registered") == true;
        if (!registered) {
          box.write("post_registration_route", Routes.EMPLOYEE_DASHBOARD);
          Get.offAllNamed(Routes.EMPLOYEE_REGISTRATION);
        } else {
          Get.offAllNamed(Routes.EMPLOYEE_DASHBOARD);
        }
        break;

      default:
        box.erase();
        Get.offAllNamed(Routes.LOGIN);
    }
  }

  // ============================
  // NORMAL LOGIN
  // ============================
  Future<void> login() async {
    clearError();

    if (username.value.trim().isEmpty || password.value.trim().isEmpty) {
      errorMessage.value = "Please enter username & password";
      return;
    }

    loading.value = true;

    dynamic res;
    try {
      res = await ApiService.post(
        ApiEndpoints.login,
        {
          "username": username.value.trim(),
          "password": password.value.trim(),
        },
      );
    } catch (_) {
      loading.value = false;
      errorMessage.value = "Network error. Please check your connection.";
      return;
    }

    loading.value = false;

    if (res == null || res is! Map) {
      errorMessage.value = "Invalid server response. Please try again.";
      return;
    }

    if (res["success"] != true) {
      errorMessage.value = res["message"] ?? "Invalid username or password";
      return;
    }

    final role       = res["role"] as String;
    final int userId = res["user_id"];

    // Persist session
    box.write("logged_in", true);
    box.write("role",      role);
    box.write("username",  username.value.trim());
    box.write("user_id",   userId);
    box.write("token",     res["token"]);

    // FIX: Use _resolveRegistration so we never wrongly write false
    final bool registered = await _resolveRegistration(
      role: role,
      userId: userId,
      loginResponse: res,
    );

    // Navigate by role
    switch (role) {
      case "master_admin":
        Get.put(MasterAdminController());
        Get.offAllNamed(Routes.MASTER_ADMIN_DASHBOARD);
        break;

      case "admin":
        Get.put(AdminController());
        Get.offAllNamed(Routes.ADMIN_DASHBOARD);
        break;

      case "special_employee":
        if (!Get.isRegistered<SpecialEmployeeController>()) {
          Get.put(SpecialEmployeeController());
        }
        if (!registered) {
          box.write("post_registration_route", Routes.SPECIAL_EMPLOYEE_DASHBOARD);
          Get.offAllNamed(Routes.EMPLOYEE_REGISTRATION);
        } else {
          Get.offAllNamed(Routes.SPECIAL_EMPLOYEE_DASHBOARD);
        }
        break;

      case "employee":
        final emp = Get.isRegistered<EmployeeController>()
            ? Get.find<EmployeeController>()
            : Get.put(EmployeeController());
        emp.setUser(userId, username.value.trim());
        if (!registered) {
          box.write("post_registration_route", Routes.EMPLOYEE_DASHBOARD);
          Get.offAllNamed(Routes.EMPLOYEE_REGISTRATION);
        } else {
          Get.offAllNamed(Routes.EMPLOYEE_DASHBOARD);
        }
        break;

      default:
        errorMessage.value = "Unknown role received. Please contact support.";
    }
  }

  // ============================
  // LOGOUT
  // ============================
  static void logout() {
    GetStorage().erase();
    if (Get.isRegistered<MasterAdminController>()) Get.delete<MasterAdminController>();
    if (Get.isRegistered<SpecialEmployeeController>()) Get.delete<SpecialEmployeeController>();
    if (Get.isRegistered<EmployeeController>()) Get.delete<EmployeeController>();
    if (Get.isRegistered<AdminController>()) Get.delete<AdminController>();
    Get.offAllNamed(Routes.LOGIN);
  }
}