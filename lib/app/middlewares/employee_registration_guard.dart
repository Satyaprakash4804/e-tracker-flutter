import 'package:flutter/material.dart'; // ✅ REQUIRED
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../routes/app_routes.dart';

class EmployeeRegistrationGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final box = GetStorage();

    final bool registered = box.read("employee_registered") == true;

    // ✅ allow login + registration always
    if (route == Routes.LOGIN ||
        route == Routes.EMPLOYEE_REGISTRATION) {
      return null;
    }

    if (!registered) {
      return const RouteSettings(
        name: Routes.EMPLOYEE_REGISTRATION,
      );
    }

    return null;
  }
}
