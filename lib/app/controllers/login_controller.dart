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

  // ============================
  // CALLED FROM main.dart / SplashScreen
  // Restores session on app cold start
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
        final bool registered = box.read("employee_registered") ?? false;
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
        final bool registered = box.read("employee_registered") ?? false;
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
      errorMessage.value = res["message"] ?? "Invalid credentials";
      return;
    }

    final role       = res["role"] as String;
    final int userId = res["user_id"];

    // ── Persist full session ──────────────────────────────────
    box.write("logged_in",          true);
    box.write("role",               role);
    box.write("username",           username.value.trim());
    box.write("user_id",            userId);
    box.write("token",              res["token"]);

    // FIX: registration_completed now comes from the API response directly —
    // no second request needed. master_admin & admin are always true server-side.
    final bool registered = res["registration_completed"] == true;
    box.write("employee_registered", registered);

    // ── Navigate by role ──────────────────────────────────────
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
  // LOGOUT (call this from any screen)
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