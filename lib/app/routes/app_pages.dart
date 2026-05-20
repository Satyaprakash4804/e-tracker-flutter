import 'package:get/get.dart';

// ROUTES
import 'app_routes.dart';

// UI PAGES
import '../ui/login/login_page.dart';
import '../ui/admin/admin_dashboard.dart';
import '../ui/admin/add_employee_page.dart';
import '../ui/admin/admin_geofence_page.dart';
import '../ui/admin/admin_employee_profile.dart';
import '../ui/admin/admin_global_geofence_page.dart';
import '../ui/master_admin/master_admin_dashboard.dart';

import '../ui/common/track_record_page.dart';

import '../ui/employee/employee_dashboard.dart';
import '../ui/employee/employee_geofence_list.dart';
import '../ui/employee/tracking_map_page.dart';
import '../ui/employee/employee_registration_page.dart';
import '../ui/employee/employee_profile_page.dart';

import '../ui/special_employee/special_employee_dashboard.dart';
import '../controllers/special_employee_controller.dart';

// CONTROLLERS
import '../controllers/login_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/employee_controller.dart';
import '../controllers/geofence_controller.dart';
import '../controllers/master_admin_controller.dart';

// MIDDLEWARE
import '../middlewares/employee_registration_guard.dart';

class AppPages {
  static const initial = Routes.LOGIN;

  static final pages = [
    // ============================
    // LOGIN
    // ============================
    GetPage(
      name: Routes.LOGIN,
      page: () => LoginPage(),
      binding: BindingsBuilder(() {
        Get.put(LoginController());
      }),
    ),

    // ============================
    // MASTER ADMIN
    // ============================
    GetPage(
      name: Routes.MASTER_ADMIN_DASHBOARD,
      page: () => const MasterAdminDashboard(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<MasterAdminController>()) {
          Get.put(MasterAdminController());
        }
      }),
    ),

    // ============================
    // ADMIN ROUTES
    // ============================
    GetPage(
      name: Routes.ADMIN_DASHBOARD,
      page: () => AdminDashboard(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AdminController>()) {
          // permanent: true keeps the controller alive when navigating to
          // sub-pages (AddEmployee, Geofence, Profile) that call Get.find<AdminController>().
          // Without permanent, GetX disposes it on route pop and sub-pages crash.
          Get.put(AdminController(), permanent: true);
        }
      }),
    ),

    GetPage(
      name: Routes.ADD_EMPLOYEE,
      page: () => AddEmployeePage(),
      binding: BindingsBuilder(() {
        // Safety net: if AdminController was somehow not yet registered
        // (e.g. deep-link or hot-reload), create it here so the page never crashes.
        if (!Get.isRegistered<AdminController>()) {
          Get.put(AdminController(), permanent: true);
        }
      }),
    ),

    GetPage(
      name: Routes.ADMIN_GEOFENCE,
      page: () => AdminGeofencePage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AdminController>()) {
          Get.put(AdminController(), permanent: true);
        }
        Get.put(GeofenceController());
      }),
    ),

    GetPage(
      name: Routes.ADMIN_EMPLOYEE_PROFILE,
      page: () => AdminEmployeeProfilePage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AdminController>()) {
          Get.put(AdminController(), permanent: true);
        }
      }),
    ),

    GetPage(
      name: Routes.ADMIN_GLOBAL_GEOFENCE,
      page: () => const AdminGlobalGeofencePage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AdminController>()) {
          Get.put(AdminController(), permanent: true);
        }
      }),
    ),

    GetPage(
      name: Routes.TRACK_RECORD,
      page: () => const TrackRecordPage(),
    ),

    GetPage(
      name: Routes.SPECIAL_EMPLOYEE_DASHBOARD,
      page: () => const SpecialEmployeeDashboard(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SpecialEmployeeController>()) {
          Get.put(SpecialEmployeeController());
        }
      }),
    ),

    // ============================
    // EMPLOYEE ROUTES
    // ============================

    /// REGISTRATION PAGE — NO guard, NO controller binding here.
    /// EmployeeController is already put() before navigating here
    /// (from login_controller or main.dart), so we must NOT recreate it.
    GetPage(
      name: Routes.EMPLOYEE_REGISTRATION,
      page: () => EmployeeRegistrationPage(),
      // FIX: Removed binding that was calling Get.put(EmployeeController())
      // unconditionally, which wiped out userId/employeeName set during login.
    ),

    /// DASHBOARD — guarded + reuses existing controller
    GetPage(
      name: Routes.EMPLOYEE_DASHBOARD,
      page: () => EmployeeDashboard(),
      binding: BindingsBuilder(() {
        // FIX: Only create a new controller if one doesn't already exist.
        // During normal login flow, login_controller already creates and
        // initialises the controller with setUser(). Re-putting it here
        // would reset employeeName and userId to empty defaults.
        if (!Get.isRegistered<EmployeeController>()) {
          // Cold-start recovery: controller not yet created.
          // Restore user data from storage so dashboard shows correct name.
          final emp = Get.put(EmployeeController());
          emp.restoreFromStorage();
        }
      }),
      middlewares: [
        EmployeeRegistrationGuard(),
      ],
    ),

    GetPage(
      name: Routes.EMPLOYEE_GEOFENCE_LIST,
      page: () => EmployeeGeofenceListPage(),
    ),

    GetPage(
      name: Routes.TRACKING_MAP,
      page: () => TrackingMapPage(),
    ),

    GetPage(
      name: Routes.EMPLOYEE_PROFILE,
      page: () => EmployeeProfilePage(),
    ),
  ];
}