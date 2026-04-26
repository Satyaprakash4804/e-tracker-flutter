import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../controllers/employee_controller.dart';
import '../../routes/app_routes.dart';
import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final EmployeeController c = Get.find<EmployeeController>();

  int? lastBatteryAlert;

  @override
  void initState() {
    super.initState();
    _initBatteryMonitor();
    // FIX: Load geofences once after frame, only if userId is valid.
    // Do NOT call loadGeofences() inside build() — it fires on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.userId > 0 && c.fences.isEmpty) {
        c.loadGeofences();
      }
    });
  }

  void _initBatteryMonitor() {
    ever(c.battery, (int batteryLevel) {
      if (batteryLevel != -1 && batteryLevel < 25) {
        if (lastBatteryAlert == null || lastBatteryAlert != batteryLevel) {
          lastBatteryAlert = batteryLevel;
          Get.snackbar(
            "⚠️ Low Battery Alert",
            "Your battery is at $batteryLevel%. Please charge your device.",
            backgroundColor: Colors.red.shade100,
            colorText: Colors.red[900],
            icon: Icon(Icons.battery_alert, color: Colors.red[700]),
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 5),
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
            isDismissible: true,
          );
        }
      } else if (batteryLevel >= 25) {
        lastBatteryAlert = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: NO Obx here at the top level. build() is a plain method.
    // Individual sections use their own Obx wrappers only around
    // the exact widgets that need to react to observable changes.

    final size = MediaQuery.of(context).size;
    final isSmallScreen  = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    final isLargeScreen  = size.width >= 900;

    return Scaffold(
      drawer: _employeeDrawer(isSmallScreen),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey[50]!, Colors.blueGrey[100]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ── (contains its own internal Obx widgets)
              _appBar(isSmallScreen),

              // ── Main Content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: isLargeScreen ? 1200 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero tracking card — Obx only wraps what changes
                          Obx(() => _heroTrackingCard(
                              c.tracking.value, isSmallScreen)),

                          const SizedBox(height: 20),

                          _quickActionsSection(isSmallScreen, isMediumScreen),

                          const SizedBox(height: 24),

                          // Location card — Obx inside the method
                          _currentLocationCard(isSmallScreen),

                          const SizedBox(height: 24),

                          // Geofences — Obx inside the method
                          _geofencesSection(isSmallScreen),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // APP BAR
  // ================================================================
  Widget _appBar(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey[700]!, Colors.blueGrey[600]!],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Builder(
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer()),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Obx only around the Text that uses the observable
                  Obx(() => Text(
                        "Welcome, ${c.employeeName.value}",
                        style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  const SizedBox(height: 4),
                  Text("Employee Dashboard",
                      style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.white.withOpacity(0.9))),
                ]),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                if (c.userId > 0) c.loadGeofences();
              },
              iconSize: isSmallScreen ? 20 : 24,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Stats row — Obx only around the stats container
        Obx(() {
          final int bat = c.battery.value;
          final bool lowBat = bat != -1 && bat < 25;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                    icon: c.tracking.value
                        ? Icons.location_on
                        : Icons.location_off,
                    label: "Tracking",
                    value: c.tracking.value ? "ACTIVE" : "INACTIVE",
                    isSmallScreen: isSmallScreen),
                Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3)),
                _statItem(
                    icon: lowBat ? Icons.battery_alert : Icons.battery_full,
                    label: "Battery",
                    value: bat == -1 ? "N/A" : "$bat%",
                    isSmallScreen: isSmallScreen),
                Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3)),
                _statItem(
                    icon: Icons.fence,
                    label: "Geofences",
                    value: c.fences.length.toString(),
                    isSmallScreen: isSmallScreen),
              ],
            ),
          );
        }),
      ]),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) =>
      Column(children: [
        Icon(icon, color: Colors.white, size: isSmallScreen ? 20 : 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.w500)),
      ]);

  // ================================================================
  // HERO TRACKING CARD
  // ================================================================
  Widget _heroTrackingCard(bool tracking, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tracking
              ? [Colors.green[400]!, Colors.green[600]!]
              : [Colors.blueGrey[700]!, Colors.blueGrey[900]!],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: (tracking ? Colors.green : Colors.blueGrey)
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(tracking ? Icons.gps_fixed : Icons.gps_off,
              size: isSmallScreen ? 48 : 64, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          tracking ? "Tracking Active" : "Tracking Inactive",
          style: TextStyle(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          tracking
              ? "Your location is being tracked in real-time"
              : "Start tracking to monitor your location",
          style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.white.withOpacity(0.9)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: isSmallScreen ? 56 : 64,
          child: ElevatedButton.icon(
            onPressed: tracking ? c.stopTracking : c.startTracking,
            icon: Icon(tracking ? Icons.stop : Icons.play_arrow,
                size: isSmallScreen ? 24 : 28),
            label: Text(
              tracking ? "Stop Tracking" : "Start Tracking",
              style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: tracking ? Colors.red : Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  // ================================================================
  // QUICK ACTIONS
  // ================================================================
  Widget _quickActionsSection(bool isSmallScreen, bool isMediumScreen) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Quick Actions",
          style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900])),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isSmallScreen ? 2 : (isMediumScreen ? 3 : 4),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isSmallScreen ? 1.3 : 1.5,
        children: [
          _quickActionCard(
              icon: Icons.map,
              title: "Live Map",
              color: Colors.blue,
              isSmallScreen: isSmallScreen,
              onTap: () => Get.toNamed(Routes.TRACKING_MAP)),
          _quickActionCard(
              icon: Icons.camera_alt,
              title: "Geo-Tagged Photo",
              color: Colors.purple,
              isSmallScreen: isSmallScreen,
              onTap: _showGeoTagPhotoDialog),
          _quickActionCard(
              icon: Icons.timeline,
              title: "Track Records",
              color: Colors.orange,
              isSmallScreen: isSmallScreen,
              onTap: () => Get.toNamed(Routes.TRACK_RECORD,
                  arguments: {
                    "user_id": c.userId,
                    "name": c.employeeName.value
                  })),
          _quickActionCard(
              icon: Icons.fence,
              title: "My Geofences",
              color: Colors.teal,
              isSmallScreen: isSmallScreen,
              onTap: () => Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST)),
        ],
      ),
    ]);
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: isSmallScreen ? 28 : 32),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[900]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  // ================================================================
  // CURRENT LOCATION CARD
  // ================================================================
  Widget _currentLocationCard(bool isSmallScreen) {
    // Obx only wraps the card that reads live observables
    return Obx(() => Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueGrey[200]!, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(Icons.my_location, color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("Current Location",
                      style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[900])),
                  Text(
                    c.lastUpdateTime.value.isEmpty
                        ? "Waiting for update…"
                        : "Updated: ${c.lastUpdateTime.value}",
                    style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blueGrey[600]),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            _locationInfoRow(
                icon: Icons.location_on,
                label: "Latitude",
                value: c.liveLat.value == 0.0
                    ? "Not available"
                    : c.liveLat.value.toStringAsFixed(6),
                isSmallScreen: isSmallScreen),
            const SizedBox(height: 10),
            _locationInfoRow(
                icon: Icons.location_on,
                label: "Longitude",
                value: c.liveLng.value == 0.0
                    ? "Not available"
                    : c.liveLng.value.toStringAsFixed(6),
                isSmallScreen: isSmallScreen),
          ]),
        ));
  }

  Widget _locationInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.blueGrey[100],
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: Colors.blueGrey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.blueGrey[600],
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);

  // ================================================================
  // GEOFENCES SECTION
  // ================================================================
  Widget _geofencesSection(bool isSmallScreen) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("My Geofences",
            style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900])),
        TextButton.icon(
          onPressed: () => Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text("View All"),
          style: TextButton.styleFrom(foregroundColor: Colors.blueGrey[700]),
        ),
      ]),
      const SizedBox(height: 12),
      // Obx only around the list that reads fences/loadingFences
      Obx(() {
        if (c.loadingFences.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child:
                  CircularProgressIndicator(color: Colors.blueGrey[700]),
            ),
          );
        }

        if (c.fences.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey[200]!),
            ),
            child: Center(
              child: Column(children: [
                Icon(Icons.fence,
                    size: isSmallScreen ? 48 : 56,
                    color: Colors.blueGrey[300]),
                const SizedBox(height: 12),
                Text("No geofences assigned",
                    style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.blueGrey[600],
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          );
        }

        final displayList =
            c.fences.length > 3 ? c.fences.sublist(0, 3) : c.fences;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          itemBuilder: (_, i) =>
              _geofenceCard(displayList[i], isSmallScreen),
        );
      }),
    ]);
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return km >= 10
          ? "${km.toStringAsFixed(1)} km"
          : "${km.toStringAsFixed(2)} km";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  Widget _geofenceCard(dynamic f, bool isSmallScreen) {
    final bool inside   = f["is_inside"] == true;
    final bool isGlobal = f["type"] == "global";

    // Safe coordinate parsing
    final fLat = (f["latitude"]  as num?)?.toDouble() ?? 0.0;
    final fLng = (f["longitude"] as num?)?.toDouble() ?? 0.0;

    final dist = (c.liveLat.value != 0.0 && c.liveLng.value != 0.0 &&
            fLat != 0.0 && fLng != 0.0)
        ? _distance(c.liveLat.value, c.liveLng.value, fLat, fLng)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: inside ? Colors.green[200]! : Colors.red[200]!, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(f["name"] ?? "Unnamed",
                style: TextStyle(
                    fontSize: isSmallScreen ? 17 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          _badge(isGlobal ? "GLOBAL" : "EMPLOYEE",
              isGlobal ? Colors.deepPurple : Colors.teal, isSmallScreen),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.radio_button_unchecked,
              size: 16, color: Colors.blueGrey[600]),
          const SizedBox(width: 6),
          Text("Radius: ${f['radius']} m",
              style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: Colors.blueGrey[700])),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: inside ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: inside ? Colors.green[200]! : Colors.red[200]!),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: inside ? Colors.green : Colors.red,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              inside ? "INSIDE GEOFENCE" : "OUTSIDE GEOFENCE",
              style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: inside ? Colors.green[900] : Colors.red[900]),
            ),
          ]),
        ),
        if (dist != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8)),
                child:
                    Icon(Icons.straighten, size: 18, color: Colors.blue[700]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("Distance from Geofence",
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(_formatDistance(dist),
                      style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold)),
                  if (dist >= 1000)
                    Text("${dist.toStringAsFixed(0)} meters",
                        style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: Colors.blue[600])),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _badge(String text, Color color, bool isSmallScreen) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Text(text,
            style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: color)),
      );

  // ================================================================
  // GEO-TAG PHOTO DIALOG
  // ================================================================
  void _showGeoTagPhotoDialog() {
    Get.dialog(
      Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.purple[50], shape: BoxShape.circle),
              child: Icon(Icons.camera_alt, size: 48, color: Colors.purple[700]),
            ),
            const SizedBox(height: 16),
            Text("Capture Geo-Tagged Photo",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900]),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            // Obx only around the text reading observables
            Obx(() => Text(
                  "Current Location:\n"
                  "${c.liveLat.value.toStringAsFixed(6)}, "
                  "${c.liveLng.value.toStringAsFixed(6)}",
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey[600]),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 8),
            Obx(() => Text(
                  "Time: ${c.lastUpdateTime.value}",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.blueGrey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text("Cancel",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey[700])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    c.captureAndUploadPhoto();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text("Capture",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ================================================================
  // DRAWER
  // ================================================================
  Drawer _employeeDrawer(bool isSmallScreen) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey[50]!, Colors.white],
          ),
        ),
        child: Column(children: [
          // FIX: Guard userId before making profile API call
          FutureBuilder(
            future: c.userId > 0
                ? ApiService.get(
                    "${ApiEndpoints.employeeProfile}/${c.userId}")
                : Future.value(null),
            builder: (context, snapshot) {
              String? selfie;
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data is Map) {
                final Map res = snapshot.data as Map;
                if (res["success"] == true &&
                    res["data"]?["selfie_path"] != null) {
                  selfie = res["data"]["selfie_path"];
                }
              }
              return Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 20,
                    left: 20,
                    right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueGrey[700]!,
                      Colors.blueGrey[600]!
                    ],
                  ),
                ),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: isSmallScreen ? 40 : 48,
                      backgroundColor: Colors.white,
                      backgroundImage: selfie != null
                          ? NetworkImage(selfie)
                          : null,
                      child: selfie == null
                          ? Icon(Icons.person,
                              size: isSmallScreen ? 40 : 48,
                              color: Colors.blueGrey[700])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Obx only around the name text
                  Obx(() => Text(c.employeeName.value,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: 4),
                  Text("Employee",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9))),
                ]),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                    icon: Icons.dashboard,
                    title: "Dashboard",
                    onTap: () => Get.back()),
                _drawerItem(
                    icon: Icons.person,
                    title: "My Profile",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.EMPLOYEE_PROFILE);
                    }),
                _drawerItem(
                    icon: Icons.timeline,
                    title: "My Track Records",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.TRACK_RECORD, arguments: {
                        "user_id": c.userId,
                        "name": c.employeeName.value
                      });
                    }),
                _drawerItem(
                    icon: Icons.map,
                    title: "Live Map",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.TRACKING_MAP);
                    }),
                _drawerItem(
                    icon: Icons.camera_alt,
                    title: "Geo-Tagged Photo",
                    onTap: () {
                      Get.back();
                      _showGeoTagPhotoDialog();
                    }),
                _drawerItem(
                    icon: Icons.fence,
                    title: "My Geofences",
                    onTap: () {
                      Get.back();
                      Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST);
                    }),
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
              Get.snackbar("Logged out", "You logged out successfully",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green[100],
                  colorText: Colors.green[900]);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: (color ?? Colors.blueGrey[700])!.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color ?? Colors.blueGrey[700], size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                color: color ?? Colors.blueGrey[900],
                fontWeight: FontWeight.w600)),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
}