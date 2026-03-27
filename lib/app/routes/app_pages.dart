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
import '../ui/employee/employee_registration_page.dart'; // ✅ NEW
import '../ui/employee/employee_profile_page.dart';

// Imports to add:
import '../ui/special_employee/special_employee_dashboard.dart';
import '../controllers/special_employee_controller.dart';
// CONTROLLERS
import '../controllers/login_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/employee_controller.dart';
import '../controllers/geofence_controller.dart';
import '../controllers/master_admin_controller.dart';

// MIDDLEWARE
import '../middlewares/employee_registration_guard.dart'; // ✅ NEW

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
    // master admin
    // ============================

    GetPage(
  name: Routes.MASTER_ADMIN_DASHBOARD,
  page: () => const MasterAdminDashboard(),
  binding: BindingsBuilder(() {
    Get.put(MasterAdminController());
  }),
),

    // ============================
    // ADMIN ROUTES
    // ============================
    GetPage(
      name: Routes.ADMIN_DASHBOARD,
      page: () => AdminDashboard(),
      binding: BindingsBuilder(() {
        Get.put(AdminController());
      }),
    ),

    GetPage(
      name: Routes.ADD_EMPLOYEE,
      page: () => AddEmployeePage(),
    ),

    GetPage(
      name: Routes.ADMIN_GEOFENCE,
      page: () => AdminGeofencePage(),
      binding: BindingsBuilder(() {
        Get.put(GeofenceController());
      }),
    ),

    GetPage(
      name: Routes.ADMIN_EMPLOYEE_PROFILE,
      page: () => AdminEmployeeProfilePage(),
    ),

    GetPage(
      name: Routes.ADMIN_GLOBAL_GEOFENCE,
      page: () => const AdminGlobalGeofencePage(),
    ),

    GetPage(
      name: Routes.TRACK_RECORD,
      page: () => const TrackRecordPage(),
    ),
    
   


    // GetPage to add:
GetPage(
  name: Routes.SPECIAL_EMPLOYEE_DASHBOARD,
  page: () => const SpecialEmployeeDashboard(),
  binding: BindingsBuilder(() {
    Get.put(SpecialEmployeeController());
  }),
),
    // ============================
    // EMPLOYEE ROUTES
    // ============================

    /// 🔐 REGISTRATION PAGE (NO GUARD)
    GetPage(
      name: Routes.EMPLOYEE_REGISTRATION,
      page: () => EmployeeRegistrationPage(),
      binding: BindingsBuilder(() {
        Get.put(EmployeeController());
      }),
    ),

    /// 🚫 DASHBOARD (GUARDED)
    GetPage(
      name: Routes.EMPLOYEE_DASHBOARD,
      page: () => EmployeeDashboard(),
      binding: BindingsBuilder(() {
        Get.put(EmployeeController());
      }),
      middlewares: [
        EmployeeRegistrationGuard(), // ⭐ STEP-4 APPLIED HERE
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
