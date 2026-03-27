import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../controllers/geofence_controller.dart';
import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class AdminGeofencePage extends StatefulWidget {
  const AdminGeofencePage({super.key});

  @override
  State<AdminGeofencePage> createState() => _AdminGeofencePageState();
}

class _AdminGeofencePageState extends State<AdminGeofencePage> {
  final GeofenceController c = Get.find<GeofenceController>();

  MapplsMapController? mapController;
  IO.Socket? socket;

  late int empId;
  String employeeName = "Employee";

  RxBool isOnline = false.obs;
  RxString lastSeenTime = "".obs;
  Rx<LatLng?> currentLocation = Rx<LatLng?>(null);

  Symbol? employeeMarker;
  final List<Fill> fenceFills = [];
  Fill? previewFill;

  final nameCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();
  final radiusCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    final args = Get.arguments;
    if (args is int) {
      empId = args;
      employeeName = "Employee";
    } else if (args is Map<String, dynamic>) {
      empId = args['empId'] as int;
      employeeName = args['empName'] ?? "Employee";
    } else {
      empId = 0;
      employeeName = "Employee";
    }

    Future.delayed(const Duration(milliseconds: 200), () async {
      await c.loadGeofences(empId);
      await _loadLatestLocation();
      await _drawGeofences();
    });

    _initSocket();
  }

  Future<void> _loadLatestLocation() async {
    try {
      final res = await ApiService.get("${ApiEndpoints.latestLocation}/$empId");

      if (res != null && res["success"] == true) {
        final lat = (res["latitude"] as num).toDouble();
        final lng = (res["longitude"] as num).toDouble();
        final timestamp = res["time"] ?? "";

        currentLocation.value = LatLng(lat, lng);
        lastSeenTime.value = timestamp;

        if (timestamp.isNotEmpty) {
          DateTime ts = DateTime.parse(timestamp);
          isOnline.value = DateTime.now().difference(ts).inSeconds <= 30;
        }

        if (mapController != null && currentLocation.value != null) {
          await _updateEmployeeMarker(currentLocation.value!);
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation.value!, 15),
          );
        }
      }
    } catch (e) {
      print("Error loading location: $e");
    }
  }

  void _initSocket() {
    socket = IO.io(
      ApiEndpoints.socketBase,
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );

    socket!.on("location_update", (data) async {
      if (data["user_id"] != empId) return;

      final lat = (data["latitude"] as num).toDouble();
      final lng = (data["longitude"] as num).toDouble();

      currentLocation.value = LatLng(lat, lng);
      isOnline.value = true;
      lastSeenTime.value = DateTime.now().toIso8601String();

      if (mapController != null) {
        await _updateEmployeeMarker(currentLocation.value!);
      }

      await c.loadGeofences(empId);
    });

    socket!.onDisconnect((_) {
      isOnline.value = false;
    });

    socket!.connect();
  }

  Future<void> _updateEmployeeMarker(LatLng pos) async {
    if (mapController == null) return;

    if (employeeMarker != null) {
      await mapController!.removeSymbol(employeeMarker!);
    }

    employeeMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: pos,
        iconSize: 1.8,
        iconColor: isOnline.value ? "#4CAF50" : "#F44336",
      ),
    );
  }

  List<LatLng> _createCirclePolygon(LatLng center, double radiusInMeters) {
    const int numPoints = 64;
    final List<LatLng> points = [];
    const double earthRadius = 6371000.0;
    
    final double angularDistance = radiusInMeters / earthRadius;
    final double centerLatRad = center.latitude * math.pi / 180;
    final double centerLngRad = center.longitude * math.pi / 180;
    
    for (int i = 0; i <= numPoints; i++) {
      final double bearing = (i * 360.0 / numPoints) * math.pi / 180;
      
      final double latRad = math.asin(
        math.sin(centerLatRad) * math.cos(angularDistance) +
        math.cos(centerLatRad) * math.sin(angularDistance) * math.cos(bearing)
      );
      
      final double lngRad = centerLngRad + math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(centerLatRad),
        math.cos(angularDistance) - math.sin(centerLatRad) * math.sin(latRad)
      );
      
      points.add(LatLng(
        latRad * 180 / math.pi,
        lngRad * 180 / math.pi,
      ));
    }
    
    return points;
  }

  bool _isPointInsideAnyGeofence(LatLng point) {
    for (final f in c.fences) {
      final center = LatLng(
        (f["latitude"] as num).toDouble(),
        (f["longitude"] as num).toDouble(),
      );
      final radius = (f["radius"] as num).toDouble();
      
      final distance = _calculateDistance(point, center);
      if (distance <= radius) {
        return true;
      }
    }
    return false;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000.0; // meters
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
              math.cos(lat1Rad) * math.cos(lat2Rad) *
              math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  Future<void> _drawGeofences() async {
    if (mapController == null) return;

    for (var fill in fenceFills) {
      try {
        await mapController!.removeFill(fill);
      } catch (e) {
        print("Error removing fill: $e");
      }
    }
    fenceFills.clear();

    for (final f in c.fences) {
      try {
        final center = LatLng(
          (f["latitude"] as num).toDouble(),
          (f["longitude"] as num).toDouble(),
        );
        final radius = (f["radius"] as num).toDouble();
        final isInside = f["is_inside"] ?? false;

        final polygon = _createCirclePolygon(center, radius);

        final fill = await mapController!.addFill(
          FillOptions(
            geometry: [polygon],
            fillColor: isInside ? "#4CAF50" : "#9C27B0",
            fillOpacity: 0.2,
            fillOutlineColor: isInside ? "#2E7D32" : "#7B1FA2",
          ),
        );

        fenceFills.add(fill);
      } catch (e) {
        print("Error drawing geofence: $e");
      }
    }
  }

  Future<void> _drawPreview() async {
    if (mapController == null) return;
    if (c.latitude.value == 0 || c.longitude.value == 0) return;
    if (c.radius.value <= 0) return;

    if (previewFill != null) {
      try {
        await mapController!.removeFill(previewFill!);
      } catch (e) {
        print("Error removing preview: $e");
      }
    }

    try {
      final polygon = _createCirclePolygon(
        LatLng(c.latitude.value, c.longitude.value),
        c.radius.value.toDouble(),
      );

      previewFill = await mapController!.addFill(
        FillOptions(
          geometry: [polygon],
          fillColor: "#FF9800",
          fillOpacity: 0.3,
          fillOutlineColor: "#F57C00",
        ),
      );
    } catch (e) {
      print("Error drawing preview: $e");
    }
  }

  String formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return "—";

    final duration = Duration(seconds: seconds);
    
    if (duration.inDays > 0) {
      return "${duration.inDays}d ${duration.inHours % 24}h";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${duration.inSeconds % 60}s";
    } else {
      return "${duration.inSeconds}s";
    }
  }

  String formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return "—";
    
    try {
      final dt = DateTime.parse(dateTime);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      final year = dt.year;
      
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      
      return "$month $day, $year ${hour.toString().padLeft(2, '0')}:$minute $period";
    } catch (e) {
      return dateTime;
    }
  }

  String getRelativeTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return "Unknown";
    
    try {
      final dt = DateTime.parse(dateTime);
      final diff = DateTime.now().difference(dt);
      
      if (diff.inSeconds < 30) return "Just now";
      if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (e) {
      return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    final isLargeScreen = size.width >= 900;

    return Scaffold(
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
              _buildHeader(isSmallScreen),
              Expanded(
                child: isLargeScreen 
                    ? _buildLargeScreenLayout() 
                    : _buildMobileLayout(isSmallScreen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Get.back(),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Geofence Management",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
                Text(
                  employeeName,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.blueGrey[600],
                  ),
                ),
              ],
            ),
          ),
          Obx(() => Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline.value 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline.value ? Colors.green : Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline.value ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  isOnline.value ? "Online" : "Offline",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline.value ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isSmallScreen) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: _buildMapWithStatus(isSmallScreen),
        ),
        Expanded(child: _buildControlPanel(isSmallScreen)),
      ],
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildMapWithStatus(false)),
        Container(
          width: 1,
          color: Colors.blueGrey[200],
        ),
        Expanded(flex: 2, child: _buildControlPanel(false)),
      ],
    );
  }

  Widget _buildMapWithStatus(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          MapplsMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 12,
            ),
            onMapCreated: (controller) async {
              mapController = controller;
              
              await Future.delayed(const Duration(milliseconds: 300));
              
              if (currentLocation.value != null) {
                await _updateEmployeeMarker(currentLocation.value!);
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation.value!, 15),
                );
              }
              
              await _drawGeofences();
            },
            onMapClick: (_, latlng) {
              // Always autofill coordinates when clicking on map
              c.latitude.value = latlng.latitude;
              c.longitude.value = latlng.longitude;
              latCtrl.text = latlng.latitude.toStringAsFixed(6);
              lngCtrl.text = latlng.longitude.toStringAsFixed(6);
              _drawPreview();
            },
            myLocationEnabled: true,
          ),
          
          // Location Info Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Obx(() => Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blueGrey[700],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Current Location",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 15,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      Spacer(),
                      Text(
                        getRelativeTime(lastSeenTime.value),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (currentLocation.value != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _infoChip(
                            "Lat",
                            currentLocation.value!.latitude.toStringAsFixed(6),
                            Icons.my_location,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _infoChip(
                            "Lng",
                            currentLocation.value!.longitude.toStringAsFixed(6),
                            Icons.explore,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (lastSeenTime.value.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      formatDateTime(lastSeenTime.value),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey[500],
                      ),
                    ),
                  ],
                ],
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blueGrey[600]),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blueGrey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isSmallScreen) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Geofence",
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
            SizedBox(height: 16),

            _inputField(
              controller: nameCtrl,
              label: "Geofence Name",
              icon: Icons.label_outline,
              onChanged: (v) => c.name.value = v,
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: 12),

            _inputField(
              controller: radiusCtrl,
              label: "Radius (meters)",
              icon: Icons.radar,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                c.radius.value = int.tryParse(v) ?? 0;
                _drawPreview();
              },
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: latCtrl,
                    label: "Latitude",
                    icon: Icons.location_on_outlined,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      c.latitude.value = double.tryParse(v) ?? 0;
                      _drawPreview();
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    controller: lngCtrl,
                    label: "Longitude",
                    icon: Icons.explore_outlined,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      c.longitude.value = double.tryParse(v) ?? 0;
                      _drawPreview();
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    Get.snackbar(
                      "Error",
                      "Please enter a geofence name",
                      backgroundColor: Colors.red[100],
                      colorText: Colors.red[900],
                      snackPosition: SnackPosition.TOP,
                      margin: EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                    return;
                  }
                  
                  if (c.radius.value <= 0) {
                    Get.snackbar(
                      "Error",
                      "Please enter a valid radius",
                      backgroundColor: Colors.red[100],
                      colorText: Colors.red[900],
                      snackPosition: SnackPosition.TOP,
                      margin: EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                    return;
                  }

                  if (c.latitude.value == 0 || c.longitude.value == 0) {
                    Get.snackbar(
                      "Error",
                      "Please select a location on the map",
                      backgroundColor: Colors.red[100],
                      colorText: Colors.red[900],
                      snackPosition: SnackPosition.TOP,
                      margin: EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                    return;
                  }

                  await c.createGeofence(empId);
                  await c.loadGeofences(empId);
                  await _drawGeofences();
                  
                  nameCtrl.clear();
                  radiusCtrl.clear();
                  latCtrl.clear();
                  lngCtrl.clear();
                  
                  if (previewFill != null) {
                    await mapController?.removeFill(previewFill!);
                    previewFill = null;
                  }

                  Get.snackbar(
                    "Success",
                    "Geofence created successfully",
                    backgroundColor: Colors.green[100],
                    colorText: Colors.green[900],
                    snackPosition: SnackPosition.TOP,
                    margin: EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                },
                icon: Icon(Icons.add_location, size: 20),
                label: Text("Create Geofence"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24),
            Divider(color: Colors.blueGrey[200]),
            SizedBox(height: 24),

            Row(
              children: [
                Text(
                  "Active Geofences",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
                Spacer(),
                Obx(() => Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${c.fences.length}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                )),
              ],
            ),
            SizedBox(height: 16),

            Obx(() {
              if (c.loadingFences.value) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      color: Colors.blueGrey[700],
                    ),
                  ),
                );
              }

              if (c.fences.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey[200]!),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 48,
                          color: Colors.blueGrey[400],
                        ),
                        SizedBox(height: 12),
                        Text(
                          "No geofences created yet",
                          style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tap on the map to start creating",
                          style: TextStyle(
                            color: Colors.blueGrey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: c.fences.length,
                itemBuilder: (_, i) {
                  final f = c.fences[i];
                  final isInside = f["is_inside"] ?? false;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isInside 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.purple.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isInside 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: isInside ? Colors.green[700] : Colors.purple[700],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        f["name"] ?? "Unnamed",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 15 : 16,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isInside ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isInside ? "Inside" : "Outside",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.radar, size: 14, color: Colors.blueGrey[600]),
                            SizedBox(width: 4),
                            Text(
                              "${f["radius"]}m",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow("Latitude", f["latitude"].toString(), isSmallScreen),
                              _detailRow("Longitude", f["longitude"].toString(), isSmallScreen),
                              _detailRow("Radius", "${f["radius"]} meters", isSmallScreen),
                              
                              SizedBox(height: 16),
                              Divider(color: Colors.blueGrey[200]),
                              SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 18,
                                    color: Colors.blueGrey[700],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Events History",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.blueGrey[900],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              
                              if (f["events"] != null && (f["events"] as List).isNotEmpty)
                                ...(f["events"] as List).map((e) => Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.login, size: 16, color: Colors.green[600]),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Entry: ${formatDateTime(e["entry_time"])}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.logout, size: 16, color: Colors.red[600]),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Exit: ${formatDateTime(e["exit_time"])}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.timer, size: 16, color: Colors.blue[600]),
                                          SizedBox(width: 8),
                                          Text(
                                            "Duration: ${formatDuration(e["duration_seconds"])}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))
                              else
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.event_busy,
                                          size: 32,
                                          color: Colors.blueGrey[400],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "No events recorded yet",
                                          style: TextStyle(
                                            color: Colors.blueGrey[600],
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              SizedBox(height: 16),
                              
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final confirm = await Get.dialog<bool>(
                                      AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: Text(
                                          "Delete Geofence",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey[900],
                                          ),
                                        ),
                                        content: Text(
                                          "Are you sure you want to delete '${f["name"]}'? This action cannot be undone.",
                                          style: TextStyle(color: Colors.blueGrey[700]),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Get.back(result: false),
                                            child: Text(
                                              "Cancel",
                                              style: TextStyle(color: Colors.blueGrey[600]),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Get.back(result: true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await c.deleteGeofence(f["id"]);
                                      await c.loadGeofences(empId);
                                      await _drawGeofences();
                                      
                                      Get.snackbar(
                                        "Success",
                                        "Geofence deleted successfully",
                                        backgroundColor: Colors.green[100],
                                        colorText: Colors.green[900],
                                        snackPosition: SnackPosition.TOP,
                                        margin: EdgeInsets.all(16),
                                        borderRadius: 12,
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.delete_outline, size: 20),
                                  label: Text("Delete Geofence"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required Function(String) onChanged,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: Colors.blueGrey[900],
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey[600]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Colors.blueGrey[600]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.blueGrey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.blueGrey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket?.disconnect();
    mapController?.dispose();
    nameCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    radiusCtrl.dispose();
    super.dispose();
  }
}