import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mappls_gl/mappls_gl.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/controllers/employee_controller.dart';
import 'app/services/version_check_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------
  // INIT STORAGE
  // ---------------------------
  await GetStorage.init();
  final box = GetStorage();

  // ---------------------------
  // GLOBAL CONTROLLERS
  // ---------------------------
  Get.put(EmployeeController(), permanent: true);

  // ---------------------------
  // MAPPLS KEYS
  // ---------------------------
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

  // ---------------------------
  // RESTORE SESSION
  // ---------------------------
  final bool loggedIn = box.read("logged_in") ?? false;
  final String role = box.read("role") ?? "";
  final int userId = box.read("user_id") ?? 0;
  final String username = box.read("username") ?? "";

  if (loggedIn && role == "employee") {
    final emp = Get.find<EmployeeController>();
    emp.setUser(userId, username);
  }

  runApp(
    ETrackerApp(
      loggedIn: loggedIn,
      role: role,
    ),
  );
}

class ETrackerApp extends StatelessWidget {
  final bool loggedIn;
  final String role;

  const ETrackerApp({
    super.key,
    required this.loggedIn,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,

      // ---------------------------
      // INITIAL ROUTE
      // ---------------------------
      initialRoute: !loggedIn
          ? Routes.LOGIN
          : (role == "admin"
              ? Routes.ADMIN_DASHBOARD
              : Routes.EMPLOYEE_DASHBOARD),

      getPages: AppPages.pages,

      // ---------------------------
      // ✅ VERSION CHECK ON START
      // ---------------------------
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          VersionCheckService.check(context);
        });
        return child!;
      },
    );
  }
}
