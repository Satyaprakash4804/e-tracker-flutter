class ApiEndpoints {
  static const String baseUrl = "http://192.168.1.11:5000/api";
  static const String socketBase = "http://192.168.1.11:5000";

  // static const String baseUrl = "https://tracker.venus360.in/api";
  // static const String socketBase = "https://tracker.venus360.in";

  static const String login = "$baseUrl/login";

  static const String getEmployees = "$baseUrl/admin/employees";
  static const String createEmployee = "$baseUrl/admin/create_employee";
  static const String deleteEmployee = "$baseUrl/admin/employee";

  static const String createGeofence = "$baseUrl/geofence/create";
  static const String listGeofence = "$baseUrl/geofence/list";
  static const String deleteGeofence = "$baseUrl/geofence/delete";

  static const String updateLocation = "$baseUrl/location/update";
  static const String latestLocation = "$baseUrl/location/latest";
  static const String trackRecords = "$baseUrl/location/track";

  static const String employeeRegistrationStatus =
      "$baseUrl/employee/registration-status";
  static const String employeeRegister = "$baseUrl/employee/register";

  static const String adminEmployeeProfile =
      "$baseUrl/admin/employee/profile";
  static const String adminUpdateEmployee =
      "$baseUrl/admin/employee/update";
  static const String uploadPhoto = "$baseUrl/employee/upload-photo";
  static const String adminEmployeeUploads =
      "$baseUrl/admin/employee/uploads";
  static const String adminDeleteUpload =
      "$baseUrl/admin/employee/upload";

  static const String createGlobalGeofence =
      "$baseUrl/geofence/global/create";
  static const String listGlobalGeofences =
      "$baseUrl/geofence/global/list";
  static const String deleteGlobalGeofence =
      "$baseUrl/geofence/global/delete";
  static const String globalGeofenceEvents =
      "$baseUrl/geofence/global/events";
  static const String globalEmployeeGeofences =
      "$baseUrl/geofence/global/employee";
  static const String updateGlobalGeofence =
      "$baseUrl/geofence/global/update";
  static const String getGlobalGeofenceEmployees =
      "$baseUrl/geofence/global/employees";

  static const String employeeProfile = "$baseUrl/employee/profile";
  static const String employeeUploads = "$baseUrl/employee/uploads";

  // ── Master Admin ──  ✅ FIXED: added $baseUrl prefix
  static const String masterUsers =
      "$baseUrl/master/users";
  static const String masterCreateUser =
      "$baseUrl/master/create_user";
  static const String masterDeleteUser =
      "$baseUrl/master/user";           // DELETE /api/master/user/:id
  static const String masterWorkingHours =
      "$baseUrl/master/working_hours";  // POST
  static const String masterControlStatus =
      "$baseUrl/master/control_status"; // GET  /api/master/control_status/:id
  static const String masterForceTracking =
      "$baseUrl/master/force_tracking"; // POST
  static const String masterForceRecording =
      "$baseUrl/master/force_recording";// POST

  // ── Special Employee ──
static const String specialControlStatus   = "$baseUrl/special/control_status";
static const String specialToggleTracking  = "$baseUrl/special/toggle_tracking";
static const String specialToggleRecording = "$baseUrl/special/toggle_recording";
}