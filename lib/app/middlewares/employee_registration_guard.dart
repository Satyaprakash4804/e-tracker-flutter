import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../routes/app_routes.dart';

class EmployeeRegistrationGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final box = GetStorage();

    final String role       = box.read("role") ?? "";
    final bool   loggedIn   = box.read("logged_in") == true;
    final bool   registered = box.read("employee_registered") == true;
    final String? token     = box.read("token");

    // ✅ Always allow login & registration page
    if (route == Routes.LOGIN || route == Routes.EMPLOYEE_REGISTRATION) {
      return null;
    }

    // 🔴 Not logged in OR token missing → login
    if (!loggedIn || token == null || token.isEmpty) {
      box.erase();
      return const RouteSettings(name: Routes.LOGIN);
    }

    // ✅ Admin bypass
    if (role == 'master_admin' || role == 'admin') {
      return null;
    }

    // 🔴 Employee not registered
    if (!registered) {
      return const RouteSettings(name: Routes.EMPLOYEE_REGISTRATION);
    }

    return null;
  }
}