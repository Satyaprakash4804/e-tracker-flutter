import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

import '../../controllers/admin_controller.dart';
import '../../routes/app_routes.dart';
import '../../constants/api_endpoints.dart';

// ============================================================
// GLOBAL ALERT CONTROLLER
// ============================================================
class AlertController extends GetxController {
  final box = GetStorage();
  
  late RxBool geofenceAlertOn;
  late RxBool batteryAlertOn;
  


  @override
  void onInit() {
    super.onInit();
    geofenceAlertOn = RxBool(box.read("geofence_alert_on") ?? true);
    batteryAlertOn = RxBool(box.read("battery_alert_on") ?? true);
  }

  void toggleGeofenceAlert(bool value) {
    geofenceAlertOn.value = value;
    box.write("geofence_alert_on", value);
  }

  void toggleBatteryAlert(bool value) {
    batteryAlertOn.value = value;
    box.write("battery_alert_on", value);
  }
}

// ============================================================
// ADMIN DASHBOARD
// ============================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminController c = Get.find<AdminController>();
  final alertCtrl = Get.put(AlertController());
  final box = GetStorage();

  late Timer _onlineRefreshTimer;
  
  final searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<dynamic, dynamic>> filteredEmployees = <Map<dynamic, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    c.loadEmployees();
    
    _onlineRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) {
      c.employees.refresh();
    });
  }

  String _formatLastUpdate(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return "Never";
  
    try {
      final dt = DateTime.parse(isoTime).toLocal();
  
      return "${dt.day.toString().padLeft(2, '0')}-"
             "${dt.month.toString().padLeft(2, '0')}-"
             "${dt.year} "
             "${dt.hour.toString().padLeft(2, '0')}:"
             "${dt.minute.toString().padLeft(2, '0')}:"
             "${dt.second.toString().padLeft(2, '0')}";
    } catch (_) {
      return "Invalid time";
    }
  }
  

  void _filterEmployees(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredEmployees.clear();
    } else {
      filteredEmployees.value = c.employees
          .where((emp) =>
              emp["username"]
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (emp["full_name"] ?? "")
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList()
          .cast<Map<dynamic, dynamic>>();
    }
  }

  List<Map<dynamic, dynamic>> _getDisplayEmployees() {
    if (searchQuery.value.isEmpty) {
      return c.employees.cast<Map<dynamic, dynamic>>();
    }
    return filteredEmployees;
  }


  // ✅ IMPROVED - More reliable online status
  bool _isOnline(Map emp) {
    final last = emp["last_update"];
    if (last == null) return false;
  
    try {
      final lastTime = DateTime.parse(last).toUtc();
      final now = DateTime.now().toUtc();
      return now.difference(lastTime).inSeconds <= 10;
    } catch (_) {
      return false;
    }
  }
  

  // ✅ NEW - Helper to get correct image URL (handles Cloudinary URLs)
  String? _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    
    // If it's already a complete URL (starts with http/https), return as-is
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    // Otherwise, construct URL with base URL
    return "${ApiEndpoints.baseUrl}$path";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    final isLargeScreen = size.width >= 900;

    return Scaffold(
      drawer: _adminDrawer(isSmallScreen),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueGrey[50]!,
              Colors.blueGrey[100]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ============================================================
              // CUSTOM APP BAR
              // ============================================================
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueGrey[700]!,
                      Colors.blueGrey[600]!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Builder(
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Admin Dashboard",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Workforce Management System",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: isSmallScreen ? 24 : 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // ============================================================
                    // STATS ROW
                    // ============================================================
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statItem(
                                icon: Icons.people,
                                label: "Total",
                                value: c.employees.length.toString(),
                                isSmallScreen: isSmallScreen,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              _statItem(
                                icon: Icons.online_prediction,
                                label: "Online",
                                value: c.employees
                                    .where((e) => _isOnline(e))
                                    .length
                                    .toString(),
                                isSmallScreen: isSmallScreen,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              _statItem(
                                icon: Icons.verified,
                                label: "Registered",
                                value: c.employees
                                    .where((e) => e["registration_completed"] == 1)
                                    .length
                                    .toString(),
                                isSmallScreen: isSmallScreen,
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              // ============================================================
              // EMPLOYEE LIST
              // ============================================================
              Expanded(
                child: Obx(() {
                  if (c.loading.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueGrey[700],
                      ),
                    );
                  }

                  if (c.employees.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: isSmallScreen ? 64 : 80,
                            color: Colors.blueGrey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No employees found",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              color: Colors.blueGrey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Get.toNamed(Routes.ADD_EMPLOYEE),
                            icon: const Icon(Icons.add),
                            label: const Text("Add Employee"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blueGrey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final displayEmployees = _getDisplayEmployees();

                  return Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                          vertical: 16,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isLargeScreen ? 1200 : double.infinity,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blueGrey[200]!,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueGrey.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: searchController,
                                onChanged: _filterEmployees,
                                decoration: InputDecoration(
                                  hintText: "Search employees by name or username...",
                                  hintStyle: TextStyle(
                                    color: Colors.blueGrey[400],
                                    fontSize: isSmallScreen ? 14 : 15,
                                  ),
                                  prefixIcon: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.search,
                                      color: Colors.blueGrey[600],
                                      size: 24,
                                    ),
                                  ),
                                  suffixIcon: Obx(() => searchQuery.value.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.blueGrey[600],
                                          ),
                                          onPressed: () {
                                            searchController.clear();
                                            _filterEmployees('');
                                          },
                                        )
                                      : const SizedBox.shrink()),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Results Count
                      if (searchQuery.value.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isLargeScreen ? 1200 : double.infinity,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      displayEmployees.isEmpty
                                          ? "No results found for \"${searchQuery.value}\""
                                          : "Found ${displayEmployees.length} result${displayEmployees.length > 1 ? 's' : ''} for \"${searchQuery.value}\"",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 14,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: searchQuery.value.isNotEmpty ? 12 : 0),

                      // Employee List or Empty Results
                      Expanded(
                        child: displayEmployees.isEmpty && searchQuery.value.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: isSmallScreen ? 64 : 80,
                                      color: Colors.blueGrey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No employees found",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        color: Colors.blueGrey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Try a different search term",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 15,
                                        color: Colors.blueGrey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.only(
                                  left: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                                  right: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                                  bottom: 80,
                                ),
                                itemCount: displayEmployees.length,
                                itemBuilder: (_, i) {
                                  final emp = displayEmployees[i];
                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isLargeScreen ? 1200 : double.infinity,
                                      ),
                                      child: _employeeCard(emp, isSmallScreen, isMediumScreen),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.ADD_EMPLOYEE),
        backgroundColor: Colors.blueGrey[700],
        icon: const Icon(Icons.person_add),
        label: Text(isSmallScreen ? "Add" : "Add Employee"),
      ),
    );
  }

  // ============================================================
  // STAT ITEM WIDGET
  // ============================================================
  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: isSmallScreen ? 20 : 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: isSmallScreen ? 10 : 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPLOYEE CARD
  // ============================================================
  Widget _employeeCard(Map emp, bool isSmallScreen, bool isMediumScreen) {
    final bool online = _isOnline(emp);
    final int? battery = emp["battery"];
    final bool lowBattery = battery != null && battery != -1 && battery < 25;
    final bool registered = emp["registration_completed"] == 1;
    final String? imageUrl = _getImageUrl(emp["selfie_path"]); // ✅ Use helper

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: online ? Colors.green[200]! : Colors.blueGrey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: online
                    ? [Colors.green[50]!, Colors.green[100]!]
                    : [Colors.blueGrey[50]!, Colors.blueGrey[100]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Get.toNamed(
                      Routes.ADMIN_EMPLOYEE_PROFILE,
                      arguments: emp["id"],
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: online ? Colors.green : Colors.blueGrey[400]!,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: isSmallScreen ? 28 : 32,
                          backgroundColor: Colors.blueGrey[200],
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: isSmallScreen ? 28 : 32,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: online ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp["username"] ?? "Unknown",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _badge(
                            text: online ? "ONLINE" : "OFFLINE",
                            color: online ? Colors.green : Colors.red,
                            isSmallScreen: isSmallScreen,
                          ),
                          _badge(
                            text: registered ? "REGISTERED" : "PENDING",
                            color: registered ? Colors.blue : Colors.orange,
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: "Location",
                  value: emp['lat'] != null
                      ? "${emp['lat']}, ${emp['lng']}"
                      : "Not available",
                  isSmallScreen: isSmallScreen,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  icon: Icons.access_time,
                  label: "Last Update",
                  value: _formatLastUpdate(emp['last_update']),
                  isSmallScreen: isSmallScreen,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  icon: Icons.battery_charging_full,
                  label: "Battery",
                  value: battery == null || battery == -1
                      ? "N/A"
                      : "$battery%",
                  valueColor: lowBattery ? Colors.red : Colors.green,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),

          // Actions Section
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  icon: Icons.person,
                  label: isSmallScreen ? "" : "Profile",
                  color: Colors.blueGrey[700]!,
                  onPressed: () => Get.toNamed(
                    Routes.ADMIN_EMPLOYEE_PROFILE,
                    arguments: emp["id"],
                  ),
                  isSmallScreen: isSmallScreen,
                ),
                _actionButton(
                  icon: Icons.timeline,
                  label: isSmallScreen ? "" : "Track",
                  color: Colors.blue[700]!,
                  onPressed: () => Get.toNamed(
                    Routes.TRACK_RECORD,
                    arguments: {
                      "user_id": emp["id"],
                      "name": emp["username"],
                    },
                  ),
                  isSmallScreen: isSmallScreen,
                ),
                _actionButton(
                  icon: Icons.map,
                  label: isSmallScreen ? "" : "Geofence",
                  color: Colors.green[700]!,
                  onPressed: () => Get.toNamed(
                    Routes.ADMIN_GEOFENCE,
                    arguments: emp["id"],
                  ),
                  isSmallScreen: isSmallScreen,
                ),
                _actionButton(
                  icon: Icons.delete,
                  label: isSmallScreen ? "" : "Delete",
                  color: Colors.red[700]!,
                  onPressed: () => c.deleteEmployee(emp["id"]),
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW WIDGET
  // ============================================================
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isSmallScreen,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.blueGrey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.blueGrey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: valueColor ?? Colors.blueGrey[900],
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTON WIDGET
  // ============================================================
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isSmallScreen,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isSmallScreen ? 18 : 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BADGE WIDGET
  // ============================================================
  Widget _badge({
    required String text,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 10 : 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // ADMIN DRAWER
  // ============================================================
  Drawer _adminDrawer(bool isSmallScreen) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blueGrey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueGrey[700]!,
                    Colors.blueGrey[600]!,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: isSmallScreen ? 48 : 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Admin Panel",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Administrator",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    icon: Icons.dashboard,
                    title: "Dashboard",
                    onTap: () => Get.back(),
                  ),
                  _drawerItem(
                    icon: Icons.person_add,
                    title: "Add Employee",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.ADD_EMPLOYEE);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.public,
                    title: "Global Geofence",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.ADMIN_GLOBAL_GEOFENCE);
                    },
                  ),
                  const Divider(height: 32, thickness: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      "Alert Settings",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Obx(() => _drawerSwitchItem(
                        icon: Icons.notifications_active,
                        title: "Geofence Alerts",
                        value: alertCtrl.geofenceAlertOn.value,
                        onChanged: (v) => alertCtrl.toggleGeofenceAlert(v),
                      )),
                  Obx(() => _drawerSwitchItem(
                        icon: Icons.battery_alert,
                        title: "Battery Alerts",
                        value: alertCtrl.batteryAlertOn.value,
                        onChanged: (v) => alertCtrl.toggleBatteryAlert(v),
                      )),
                ],
              ),
            ),

            const Divider(height: 1),
            _drawerItem(
              icon: Icons.logout,
              title: "Logout",
              color: Colors.red,
              onTap: () {
                GetStorage().erase();
                Get.offAllNamed(Routes.LOGIN);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER ITEM WIDGET
  // ============================================================
  Widget _drawerItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? Colors.blueGrey[700])!.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? Colors.blueGrey[700], size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.blueGrey[900],
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // ============================================================
  // DRAWER SWITCH ITEM WIDGET
  // ============================================================
  Widget _drawerSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey[200]!),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blueGrey[700], size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey[900],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueGrey[700],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  @override
  void dispose() {
    _onlineRefreshTimer.cancel();
    searchController.dispose();
    super.dispose();
  }

}