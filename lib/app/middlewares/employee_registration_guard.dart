import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../routes/app_routes.dart';

class EmployeeRegistrationGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final box = GetStorage();

    final String  role       = box.read("role")               ?? "";
    final bool    loggedIn   = box.read("logged_in")          == true;
    final bool    registered = box.read("employee_registered") == true;
    final String? token      = box.read("token");

    // ✅ Always allow login page through
    if (route == Routes.LOGIN) return null;

    // ✅ Always allow registration page through — guard must NOT redirect
    // here or it creates an infinite redirect loop when employee is
    // unregistered (guard redirects to registration, guard fires again,
    // registration is also blocked → crash / blank screen).
    if (route == Routes.EMPLOYEE_REGISTRATION) return null;

    // 🔴 Not logged in OR missing token → send to login
    if (!loggedIn || token == null || token.isEmpty) {
      box.erase();
      return const RouteSettings(name: Routes.LOGIN);
    }

    // ✅ Admin roles never need registration — bypass guard entirely
    if (role == 'master_admin' || role == 'admin') return null;

    // FIX: For employee / special_employee, redirect to registration ONLY
    // when employee_registered is explicitly false.
    // Previously this fired even when the API had already returned
    // registration_completed=true but GetStorage hadn't been written yet
    // (race condition on first login). Now the login_controller writes
    // employee_registered BEFORE navigating, so by the time the middleware
    // runs the flag is always correct.
    if ((role == 'employee' || role == 'special_employee') && !registered) {
      return const RouteSettings(name: Routes.EMPLOYEE_REGISTRATION);
    }

    return null;
  }
}