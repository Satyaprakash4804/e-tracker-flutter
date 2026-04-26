import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mappls_gl/mappls_gl.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/controllers/employee_controller.dart';
import 'app/controllers/special_employee_controller.dart';
import 'app/controllers/master_admin_controller.dart';
import 'app/controllers/admin_controller.dart';
import 'app/services/version_check_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();
  final box = GetStorage();

  // ── Mappls SDK keys ──────────────────────────────────────────
  MapplsAccountManager.setMapSDKKey(
    "425ddc32f3f0804e17759093b419b7c1",
  );
  MapplsAccountManager.setRestAPIKey(
    "425ddc32f3f0804e17759093b419b7c1",
  );
  MapplsAccountManager.setAtlasClientId(
    "96dHZVzsAutM-QgqZkpIgMIElHDAROdmtsJMu1Iyfiq7w3cjgvx0IxST_h0Ks0byMFpNX0VkQMmKgbyCnCMdRQ==",
  );
  MapplsAccountManager.setAtlasClientSecret(
    "lrFxI-iSEg8l1bHwBPApQm8q7Bti1e6d786Y0tXnzUV8030fiz4xXymqWP0zMDM1VOoZJefcj85eSXJlY7Tm-r4bz_JFSvXS",
  );

  // ── Read stored session ──────────────────────────────────────
  final bool   loggedIn = box.read("logged_in") ?? false;
  final String role     = box.read("role")      ?? "";
  final int    userId   = box.read("user_id")   ?? 0;
  final String username = box.read("username")  ?? "";

  // ── Restore controllers by role ──────────────────────────────
  // FIX: Previously only "employee" was restored here.
  // All roles need their controllers registered so that:
  //   1. Routes work immediately on reopen after app kill
  //   2. For employee/special_employee, tracking restarts automatically
  //      via loadControlStatus() / startTracking() in onInit()
  String initialRoute = Routes.LOGIN;

  if (loggedIn) {
    switch (role) {

      case "master_admin":
        // FIX: Was missing — after app kill, master_admin was sent to
        // login because no controller was registered and no route was set
        Get.put(MasterAdminController(), permanent: true);
        initialRoute = Routes.MASTER_ADMIN_DASHBOARD;
        break;

      case "admin":
        Get.put(AdminController(), permanent: true);
        initialRoute = Routes.ADMIN_DASHBOARD;
        break;

      case "special_employee":
        // FIX: Was missing — special_employee never restarted their
        // controller, so tracking/recording never resumed after app kill.
        // SpecialEmployeeController.onInit() calls loadControlStatus()
        // which restarts the native service if tracking was ON.
        Get.put(SpecialEmployeeController(), permanent: true);
        final bool registered = box.read("employee_registered") ?? false;
        if (!registered) {
          box.write("post_registration_route", Routes.SPECIAL_EMPLOYEE_DASHBOARD);
          initialRoute = Routes.EMPLOYEE_REGISTRATION;
        } else {
          initialRoute = Routes.SPECIAL_EMPLOYEE_DASHBOARD;
        }
        break;

      case "employee":
        final emp = Get.put(EmployeeController(), permanent: true);
        emp.setUser(userId, username);
        final bool registered = box.read("employee_registered") ?? false;
        if (!registered) {
          box.write("post_registration_route", Routes.EMPLOYEE_DASHBOARD);
          initialRoute = Routes.EMPLOYEE_REGISTRATION;
        } else {
          initialRoute = Routes.EMPLOYEE_DASHBOARD;
        }
        break;

      default:
        // Unknown role — clear session and go to login
        box.erase();
        initialRoute = Routes.LOGIN;
    }
  }

  runApp(ETrackerApp(initialRoute: initialRoute));
}

class ETrackerApp extends StatelessWidget {
  final String initialRoute;

  const ETrackerApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          VersionCheckService.check(context);
        });
        return child!;
      },
    );
  }
}