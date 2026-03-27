import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mappls_gl/mappls_gl.dart';

import '../../controllers/employee_controller.dart';

class TrackingMapPage extends StatefulWidget {
  const TrackingMapPage({super.key});

  @override
  State<TrackingMapPage> createState() => _TrackingMapPageState();
}

class _TrackingMapPageState extends State<TrackingMapPage> {
  final EmployeeController c = Get.find<EmployeeController>();

  MapplsMapController? map;
  bool styleLoaded = false;
  final List<Circle> _geofenceCircles = [];
  Circle? _employeeDot;
  Circle? _employeePulse;

  // ================= MAP CREATED =================
  void _onMapCreated(MapplsMapController controller) {
    map = controller;
  }

  // ================= STYLE LOADED =================
  void _onStyleLoaded() {
    styleLoaded = true;

    _drawGeofences();
    _drawEmployeeDot();
    _autoZoomToEmployee();

    // 🔁 Update when location changes
    ever(c.liveLat, (_) => _updateEmployeeDot());
  }

  // ================= EMPLOYEE DOT (BLUE PULSING) =================
  Future<void> _drawEmployeeDot() async {
    if (!styleLoaded || map == null) return;
    if (c.liveLat.value == 0 || c.liveLng.value == 0) return;

    final location = LatLng(c.liveLat.value, c.liveLng.value);

    // Remove old employee markers
    if (_employeeDot != null) {
      await map!.removeCircle(_employeeDot!);
    }
    if (_employeePulse != null) {
      await map!.removeCircle(_employeePulse!);
    }

    // Outer pulse (light blue)
    _employeePulse = await map!.addCircle(
      CircleOptions(
        geometry: location,
        circleRadius: 20,
        circleColor: "#4285F4",
        circleOpacity: 0.2,
        circleBlur: 0.5,
      ),
    );

    // Inner blue dot
    _employeeDot = await map!.addCircle(
      CircleOptions(
        geometry: location,
        circleRadius: 10,
        circleColor: "#4285F4",
        circleOpacity: 1.0,
        circleStrokeWidth: 3,
        circleStrokeColor: "#FFFFFF",
        circleStrokeOpacity: 1.0,
      ),
    );
  }

  Future<void> _updateEmployeeDot() async {
    if (map == null) return;

    // Clear and redraw everything
    await _clearAllMarkers();
    await _drawGeofences();
    await _drawEmployeeDot();
  }

  Future<void> _clearAllMarkers() async {
    // Remove geofence circles
    for (final circle in _geofenceCircles) {
      await map!.removeCircle(circle);
    }
    _geofenceCircles.clear();

    // Remove employee markers
    if (_employeeDot != null) {
      await map!.removeCircle(_employeeDot!);
      _employeeDot = null;
    }
    if (_employeePulse != null) {
      await map!.removeCircle(_employeePulse!);
      _employeePulse = null;
    }
  }

  // ================= GEOFENCES WITH GRADIENT =================
  Future<void> _drawGeofences() async {
    if (map == null) return;

    for (final f in c.fences) {
      final bool isGlobal = f["type"] == "global";
      final bool inside = f["is_inside"] == true;

      final center = LatLng(f["latitude"], f["longitude"]);
      final radiusMeters = (f["radius"] as num).toDouble();

      // 🎨 COLOR LOGIC
      String fillColor;
      String strokeColor;
      String gradientInner;
      String gradientOuter;

      if (isGlobal) {
        // 🌐 GLOBAL GEOFENCE
        if (inside) {
          fillColor = "#009688";  // 🟦 Greenish-Blue
          strokeColor = "#00796B";
          gradientInner = "#009688";
          gradientOuter = "#00796B";
        } else {
          fillColor = "#9C27B0";  // 🟣 Purple
          strokeColor = "#7B1FA2";
          gradientInner = "#9C27B0";
          gradientOuter = "#7B1FA2";
        }
      } else {
        // 👤 EMPLOYEE GEOFENCE
        if (inside) {
          fillColor = "#4CAF50";  // 🟢 Green
          strokeColor = "#388E3C";
          gradientInner = "#4CAF50";
          gradientOuter = "#388E3C";
        } else {
          fillColor = "#FF9800";  // 🟠 Orange
          strokeColor = "#F57C00";
          gradientInner = "#FF9800";
          gradientOuter = "#F57C00";
        }
      }

      // Draw gradient layers (inner to outer)
      final gradientLayers = 8;
      for (int layer = 0; layer < gradientLayers; layer++) {
        final layerRadius = radiusMeters * (1 - (layer / gradientLayers));
        final opacity = 0.25 - (layer * 0.02); // Fade outward
        
        final points = _generateCirclePoints(center, layerRadius, 48);
        
        for (int i = 0; i < points.length; i += 3) {
          final circle = await map!.addCircle(
            CircleOptions(
              geometry: points[i],
              circleRadius: 4,
              circleColor: layer < gradientLayers / 2 ? gradientInner : gradientOuter,
              circleOpacity: opacity,
            ),
          );
          _geofenceCircles.add(circle);
        }
      }

      // Draw border (stroke)
      final borderPoints = _generateCirclePoints(center, radiusMeters, 80);
      for (int i = 0; i < borderPoints.length; i += 1) {
        final circle = await map!.addCircle(
          CircleOptions(
            geometry: borderPoints[i],
            circleRadius: 3,
            circleColor: strokeColor,
            circleOpacity: 0.7,
          ),
        );
        _geofenceCircles.add(circle);
      }
    }
  }

  // ================= CIRCLE GEOMETRY =================
  List<LatLng> _generateCirclePoints(LatLng center, double radiusMeters, int steps) {
    final List<LatLng> points = [];

    for (int i = 0; i <= steps; i++) {
      final double angle = (i * 360 / steps) * math.pi / 180;
      points.add(_destinationPoint(center, radiusMeters, angle));
    }
    return points;
  }

  LatLng _destinationPoint(LatLng center, double distance, double bearing) {
    const double earthRadius = 6371000;
    final double lat1 = center.latitude * math.pi / 180;
    final double lon1 = center.longitude * math.pi / 180;
    final double d = distance / earthRadius;

    final double lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(bearing),
    );

    final double lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  // ================= AUTO ZOOM TO EMPLOYEE =================
  void _autoZoomToEmployee() {
    if (map == null) return;
    if (c.liveLat.value == 0 || c.liveLng.value == 0) return;

    map!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(c.liveLat.value, c.liveLng.value),
        15,
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  // ================= ONLINE / OFFLINE =================
  bool get isOnline {
    if (c.lastUpdateTime.value.isEmpty) return false;
    try {
      final last = DateTime.parse(c.lastUpdateTime.value).toLocal();
      return DateTime.now().difference(last).inSeconds <= 15;
    } catch (_) {
      return false;
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // MAP
          MapplsMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 12,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            compassEnabled: true,
            myLocationEnabled: false,
          ),

          // GRADIENT OVERLAY (TOP)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // STATUS CHIP
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: Obx(() {
              final online = isOnline;
              return Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: online ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: online ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        online ? "Online" : "Offline",
                        style: TextStyle(
                          color: online ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: Material(
              elevation: 6,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => Get.back(),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black87,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 📍 PINPOINT BUTTON (FLOATING - Right Side)
          Positioned(
            bottom: 32,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                onTap: _autoZoomToEmployee,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // INFO CARD (BOTTOM) with Navigate Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              if (c.liveLat.value == 0 || c.liveLng.value == 0) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4285F4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Current Location",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        // Navigate Button
                        Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: _autoZoomToEmployee,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Navigate",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile(
                            icon: Icons.near_me,
                            label: "Latitude",
                            value: c.liveLat.value.toStringAsFixed(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTile(
                            icon: Icons.place,
                            label: "Longitude",
                            value: c.liveLng.value.toStringAsFixed(6),
                          ),
                        ),
                      ],
                    ),
                    if (c.lastUpdateTime.value.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoTile(
                        icon: Icons.access_time_rounded,
                        label: "Last Update",
                        value: _formatTimestamp(c.lastUpdateTime.value),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4285F4)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (_) {
      return timestamp;
    }
  }

  @override
  void dispose() {
    _clearAllMarkers();
    super.dispose();
  }
}