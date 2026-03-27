import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mappls_gl/mappls_gl.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/global_geofence_controller.dart';
import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class AdminGlobalGeofencePage extends StatefulWidget {
  const AdminGlobalGeofencePage({super.key});

  @override
  State<AdminGlobalGeofencePage> createState() =>
      _AdminGlobalGeofencePageState();
}

class _AdminGlobalGeofencePageState extends State<AdminGlobalGeofencePage> {
  final AdminController admin = Get.find();
  final GlobalGeofenceController gc = Get.put(GlobalGeofenceController());

  MapplsMapController? map;
  Fill? currentGeofenceFill;
  final List<Fill> existingGeofenceFills = [];
  bool _isMapReady = false;
  bool _isLoadingMarkers = false;
  bool _isLoadingGeofences = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController radiusController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    radiusController.text = '100';
    gc.radius.value = 100;
    
    ever(gc.latitude, (_) => _updateLatField());
    ever(gc.longitude, (_) => _updateLngField());
    ever(gc.radius, (_) => _updateGeofenceCircle());

    ever(admin.employees, (_) async {
      if (_isMapReady) {
        await _addEmployeeMarkers();
      }
    });
  }

  void _updateLatField() {
    if (!latController.text.contains(gc.latitude.value.toString())) {
      latController.text = gc.latitude.value.toStringAsFixed(6);
    }
  }

  void _updateLngField() {
    if (!lngController.text.contains(gc.longitude.value.toString())) {
      lngController.text = gc.longitude.value.toStringAsFixed(6);
    }
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
      points.add(LatLng(latRad * 180 / math.pi, lngRad * 180 / math.pi));
    }
    return points;
  }

  void _onMapCreated(MapplsMapController controller) async {
    print("Map created callback triggered");
    map = controller;
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isMapReady = true;
    });
    print("Map is ready, starting to load content");
    await _loadAndDrawGeofences();
    await _loadEmployeeMarkers();
    await Future.delayed(const Duration(milliseconds: 500));
    _fitAllEmployees();
    print("All map content loaded successfully");
  }

  Future<void> _loadAndDrawGeofences() async {
    if (!_isMapReady || map == null) {
      print("Map not ready for geofences");
      return;
    }
    setState(() {
      _isLoadingGeofences = true;
    });
    try {
      print("Loading global geofences...");
      await gc.loadGlobalGeofences();
      await Future.delayed(const Duration(milliseconds: 200));
      print("Drawing ${gc.globalFences.length} geofences on map");
      await _drawExistingGeofences();
      print("Geofences loaded and drawn successfully");
    } catch (e) {
      print("Error loading geofences: $e");
    } finally {
      setState(() {
        _isLoadingGeofences = false;
      });
    }
  }

  Future<void> _loadEmployeeMarkers() async {
    if (!_isMapReady || map == null) {
      print("Map not ready for markers");
      return;
    }
    setState(() {
      _isLoadingMarkers = true;
    });
    try {
      print("Loading employee markers...");
      await _addEmployeeMarkers();
      print("Employee markers loaded successfully");
    } catch (e) {
      print("Error loading markers: $e");
    } finally {
      setState(() {
        _isLoadingMarkers = false;
      });
    }
  }

  void _onMapClick(math.Point<double> p, LatLng latLng) {
    gc.latitude.value = latLng.latitude;
    gc.longitude.value = latLng.longitude;
    _updateGeofenceCircle();
  }

  Future<void> _updateGeofenceCircle() async {
    if (!_isMapReady || map == null) return;
    if (gc.latitude.value == 0.0 || gc.longitude.value == 0.0) return;
    if (gc.radius.value <= 0) return;

    if (currentGeofenceFill != null) {
      try {
        await map!.removeFill(currentGeofenceFill!);
      } catch (e) {
        print("Error removing fill: $e");
      }
    }

    try {
      final polygon = _createCirclePolygon(
        LatLng(gc.latitude.value, gc.longitude.value),
        gc.radius.value.toDouble(),
      );
      currentGeofenceFill = await map!.addFill(
        FillOptions(
          geometry: [polygon],
          fillColor: "#4CAF50",
          fillOpacity: 0.3,
          fillOutlineColor: "#2E7D32",
        ),
      );
    } catch (e) {
      print("Error creating geofence fill: $e");
    }
  }

  Future<void> _drawExistingGeofences() async {
    if (!_isMapReady || map == null) {
      print("Map not ready for drawing geofences");
      return;
    }

    for (var fill in existingGeofenceFills) {
      try {
        await map!.removeFill(fill);
      } catch (e) {
        print("Error removing existing fill: $e");
      }
    }
    existingGeofenceFills.clear();

    print("Drawing ${gc.globalFences.length} existing geofences");

    for (final fence in gc.globalFences) {
      if (fence["latitude"] == null || fence["longitude"] == null) {
        print("Skipping geofence ${fence["name"]}: missing coordinates");
        continue;
      }
      if (fence["radius"] == null) {
        print("Skipping geofence ${fence["name"]}: missing radius");
        continue;
      }

      try {
        final polygon = _createCirclePolygon(
          LatLng(
            (fence["latitude"] as num).toDouble(),
            (fence["longitude"] as num).toDouble(),
          ),
          (fence["radius"] as num).toDouble(),
        );

        final fill = await map!.addFill(
          FillOptions(
            geometry: [polygon],
            fillColor: "#2196F3",
            fillOpacity: 0.2,
            fillOutlineColor: "#1976D2",
          ),
        );
        existingGeofenceFills.add(fill);
        print("Drew geofence: ${fence["name"]}");
      } catch (e) {
        print("Error drawing geofence ${fence["name"]}: $e");
      }
    }
    print("Finished drawing geofences. Total: ${existingGeofenceFills.length}");
  }

  

  Future<Uint8List> _buildMarker({
    required String imageUrl,
    required bool online,
  }) async {
    const size = 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = Colors.white,
    );

    final ringPaint = Paint()
      ..color = online ? Colors.green : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      ringPaint,
    );

    try {
      final image = await _loadNetworkImage(imageUrl);
      final rect = Rect.fromLTWH(12, 12, size - 24, size - 24);
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint(),
      );
      canvas.restore();
    } catch (e) {
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 12,
        Paint()..color = Colors.grey,
      );
    }

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
  // ✅ SAFETY: validate URL early
  if (url.isEmpty || !url.startsWith("http")) {
    throw Exception("Invalid image URL");
  }

  final completer = Completer<ui.Image>();
  final imageStream = NetworkImage(url).resolve(const ImageConfiguration());

  late final ImageStreamListener listener;

  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  imageStream.addListener(listener);

  try {
    return await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException("Image load timeout");
      },
    );
  } finally {
    imageStream.removeListener(listener);
  }
}


  Future<void> _addEmployeeMarkers() async {
    if (!_isMapReady || map == null) {
      print("Map not ready for adding markers");
      return;
    }
    
    try {
      await map!.clearSymbols();
    } catch (e) {
      print("Error clearing symbols: $e");
    }

    final baseUrl = ApiEndpoints.baseUrl.replaceAll("/api", "");
    print("Loading ${admin.employees.length} employee markers...");

    int successCount = 0;
    int failCount = 0;

    for (final emp in admin.employees) {
      if (emp["lat"] == null || emp["lng"] == null) {
        print("Skipping employee ${emp["username"]}: missing coordinates");
        failCount++;
        continue;
      }

      try {
        String imageUrl = emp["selfie_path"] != null
            ? emp["selfie_path"]
            : "";

        print("Creating marker for ${emp["username"]} at ${emp["lat"]}, ${emp["lng"]}");

        final markerBytes = await _buildMarker(
          imageUrl: imageUrl,
          online: admin.isEmployeeOnline(emp["id"]),

        );

        final imageId = "emp_${emp["id"]}_${DateTime.now().millisecondsSinceEpoch}";
        await map!.addImage(imageId, markerBytes);

        await map!.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              (emp["lat"] as num).toDouble(),
              (emp["lng"] as num).toDouble(),
            ),
            iconImage: imageId,
            iconSize: 0.7,
            textField: emp["username"] ?? "Employee",
            textOffset: const Offset(0, 2),
            textSize: 12,
            textColor: "#000000",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 2,
          ),
        );

        successCount++;
        print("✓ Successfully added marker for ${emp["username"]}");
      } catch (e) {
        failCount++;
        print("✗ Error adding marker for ${emp["username"]}: $e");
      }
    }
    print("Marker loading complete: $successCount success, $failCount failed");
  }

  void _fitAllEmployees() {
    if (!_isMapReady || map == null) {
      print("Map not ready for fitting bounds");
      return;
    }

    final valid = admin.employees
        .where((e) => e["lat"] != null && e["lng"] != null)
        .toList();

    if (valid.isEmpty) {
      print("No employees with coordinates to fit on map");
      return;
    }

    print("Fitting ${valid.length} employees on map");

    final lats = valid.map((e) => (e["lat"] as num).toDouble()).toList();
    final lngs = valid.map((e) => (e["lng"] as num).toDouble()).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // If all employees are at the same location
    if (minLat == maxLat && minLng == maxLng) {
      map!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
      );
      return;
    }

    // Add padding to bounds to ensure all markers are visible
    final latPadding = (maxLat - minLat) * 0.1; // 10% padding
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    try {
      map!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 80,
          top: 80,
          right: 80,
          bottom: 80,
        ),
      );
      print("Successfully fitted bounds for ${valid.length} employees");
    } catch (e) {
      print("Error fitting bounds: $e");
      // Fallback to center
      map!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          12,
        ),
      );
    }
  }

  void _showEditEmployees(Map geofence) async {
    final assignedIds = RxList<int>([]);
    final isAssignedToAll = RxBool(false);
    
    try {
      final res = await ApiService.get(
        "${ApiEndpoints.getGlobalGeofenceEmployees}/${geofence["id"]}"
      );
      if (res["employee_ids"] != null && res["employee_ids"] is List) {
        assignedIds.value = List<int>.from(res["employee_ids"]);
        if (assignedIds.length == admin.employees.length) {
          isAssignedToAll.value = true;
        }
      }
    } catch (e) {
      print("Error fetching assigned employees: $e");
    }

    final baseUrl = ApiEndpoints.baseUrl.replaceAll("/api", "");

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, size: 24, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Manage Employees",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            geofence["name"] ?? "Geofence",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Obx(() => Card(
                margin: const EdgeInsets.all(8),
                color: isAssignedToAll.value ? Colors.blue.withOpacity(0.1) : null,
                child: SwitchListTile(
                  title: const Text("Assign to all employees", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Apply this geofence to everyone"),
                  value: isAssignedToAll.value,
                  onChanged: (v) {
                    isAssignedToAll.value = v;
                    if (v) {
                      assignedIds.clear();
                      assignedIds.addAll(admin.employees.map((e) => e["id"] as int));
                    }
                  },
                  activeColor: Colors.blueGrey[700],
                ),
              )),
              Flexible(
                child: Obx(() {
                  if (isAssignedToAll.value) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group, size: 64, color: Colors.blueGrey[600]),
                            const SizedBox(height: 16),
                            Text(
                              "Assigned to All Employees",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "This geofence applies to everyone",
                              style: TextStyle(color: Colors.blueGrey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: admin.employees.length,
                    itemBuilder: (_, i) {
                      final emp = admin.employees[i];
                      final isAssigned = assignedIds.contains(emp["id"]);
                      final selfieUrl = emp["selfie_path"];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: isAssigned ? 2 : 1,
                        color: isAssigned ? Colors.green.withOpacity(0.05) : null,
                        child: CheckboxListTile(
                          value: isAssigned,
                          onChanged: (value) {
                            if (value == true) {
                              assignedIds.add(emp["id"]);
                            } else {
                              assignedIds.remove(emp["id"]);
                            }
                          },
                          activeColor: Colors.blueGrey[700],
                          secondary: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isAssigned ? Colors.green : Colors.grey, width: 2),
                            ),
                            child: ClipOval(
                              child: selfieUrl != null
                                  ? Image.network(selfieUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildEmployeeAvatar(emp, isAssigned))
                                  : _buildEmployeeAvatar(emp, isAssigned),
                            ),
                          ),
                          title: Text(emp["username"] ?? "Unknown", style: TextStyle(fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(emp["email"] ?? "", style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  );
                }),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey[700],
                          side: BorderSide(color: Colors.blueGrey[300]!),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final updateData = {
                              "name": geofence["name"],
                              "latitude": geofence["latitude"],
                              "longitude": geofence["longitude"],
                              "radius": geofence["radius"],
                              "assign_all": isAssignedToAll.value,
                              "employee_ids": assignedIds.toList(),
                            };
                            await ApiService.post("${ApiEndpoints.updateGlobalGeofence}/${geofence["id"]}", updateData);
                            Get.back();
                            Get.snackbar(
                              "Success",
                              "Employee assignments updated",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                            await _loadAndDrawGeofences();
                          } catch (e) {
                            Get.snackbar(
                              "Error",
                              "Failed to update assignments: $e",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 3),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Save Changes"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeAvatar(Map emp, bool isAssigned) {
    return Container(
      color: isAssigned ? Colors.green : Colors.grey,
      child: Center(
        child: Text(
          emp["username"]?[0]?.toUpperCase() ?? "?",
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showEvents(int geofenceId, String geofenceName) async {
    final res = await ApiService.get(ApiEndpoints.globalGeofenceEvents);
    final allEvents = (res["events"] as List);
    final geofenceEvents = allEvents.where((e) => e["geofence_id"] == geofenceId).toList();
    final baseUrl = ApiEndpoints.baseUrl.replaceAll("/api", "");

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueGrey[700]!,
                      Colors.blueGrey[600]!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timeline, size: 24, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Geofence Events",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            geofenceName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: geofenceEvents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Colors.blueGrey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No events found",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueGrey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: geofenceEvents.length,
                        itemBuilder: (_, i) {
                          final e = geofenceEvents[i];
                          final isActive = e["exit_time"] == null;
                          final employee = admin.employees.firstWhere((emp) => emp["id"] == e["employee_id"], orElse: () => {});
                          final selfieUrl = employee["selfie_path"];


                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isActive ? Colors.green : Colors.grey, width: 3),
                                    ),
                                    child: ClipOval(
                                      child: selfieUrl != null
                                          ? Image.network(selfieUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildAvatarFallback(e["username"], isActive))
                                          : _buildAvatarFallback(e["username"], isActive),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(e["username"] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            if (isActive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                                                child: const Text("ACTIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                              child: const Icon(Icons.login, size: 16, color: Colors.green),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Entry", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                  Text(e["entry_time"] ?? "-", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: isActive ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Icon(Icons.logout, size: 16, color: isActive ? Colors.orange : Colors.red),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Exit", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                  Text(
                                                    e["exit_time"] ?? "Still inside",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      fontStyle: isActive ? FontStyle.italic : FontStyle.normal,
                                                      color: isActive ? Colors.orange : Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String? username, bool isActive) {
    return Container(
      color: isActive ? Colors.green : Colors.grey,
      child: Center(
        child: Text(
          username?[0]?.toUpperCase() ?? "?",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    radiusController.dispose();
    latController.dispose();
    lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Global Geofences"),
        elevation: 2,
        flexibleSpace: Container(
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
        ),
        actions: [
          if (_isLoadingMarkers || _isLoadingGeofences)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
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
        child: isSmallScreen ? _buildMobileLayout() : _buildLargeScreenLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildMap()),
        Expanded(flex: 4, child: _buildControlPanel()),
      ],
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildMap()),
        Expanded(flex: 2, child: _buildControlPanel()),
      ],
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        MapplsMap(
          initialCameraPosition: const CameraPosition(target: LatLng(28.6139, 77.2090), zoom: 12),
          onMapCreated: _onMapCreated,
          onMapClick: _onMapClick,
          myLocationEnabled: true,
        ),
        if (_isLoadingMarkers || _isLoadingGeofences)
          Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueGrey[700]),
                      const SizedBox(height: 12),
                      Text(
                        "Loading map data...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueGrey[100]!,
                    Colors.blueGrey[50]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_location_alt, color: Colors.blueGrey[700], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "Create Geofence",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              onChanged: (v) => gc.name.value = v,
              decoration: InputDecoration(
                labelText: "Geofence Name",
                prefixIcon: Icon(Icons.label, color: Colors.blueGrey[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey[700]!, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) {
                  gc.radius.value = parsed;
                  _updateGeofenceCircle();
                }
              },
              decoration: InputDecoration(
                labelText: "Radius (meters)",
                prefixIcon: Icon(Icons.radar, color: Colors.blueGrey[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey[700]!, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) {
                        gc.latitude.value = parsed;
                        _updateGeofenceCircle();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Latitude",
                      prefixIcon: Icon(Icons.location_on, color: Colors.blueGrey[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey[700]!, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) {
                        gc.longitude.value = parsed;
                        _updateGeofenceCircle();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Longitude",
                      prefixIcon: Icon(Icons.location_on, color: Colors.blueGrey[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey[700]!, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() => Card(
                  elevation: 2,
                  color: gc.assignAll.value ? Colors.blue.withOpacity(0.1) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: gc.assignAll.value ? Colors.blue : Colors.blueGrey[200]!,
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      "Assign to all employees",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Apply this geofence to everyone"),
                    value: gc.assignAll.value,
                    onChanged: (v) => gc.assignAll.value = v,
                    activeColor: Colors.blueGrey[700],
                  ),
                )),
            Obx(() {
              if (gc.assignAll.value) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "Select Employees:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...admin.employees.map((emp) {
                    final isSelected = gc.selectedEmployeeIds.contains(emp["id"]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: isSelected ? 2 : 1,
                      color: isSelected ? Colors.green.withOpacity(0.05) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? Colors.green : Colors.blueGrey[200]!,
                        ),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          emp["username"] ?? "Unknown",
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (v) {
                          v == true ? gc.selectedEmployeeIds.add(emp["id"]) : gc.selectedEmployeeIds.remove(emp["id"]);
                        },
                        activeColor: Colors.blueGrey[700],
                      ),
                    );
                  }),
                ],
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (gc.name.value.isEmpty) {
                    Get.snackbar(
                      "Error",
                      "Please enter a geofence name",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  if (gc.latitude.value == 0.0 || gc.longitude.value == 0.0) {
                    Get.snackbar(
                      "Error",
                      "Please select a location on the map",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  await gc.createGlobalGeofence();
                  await _loadAndDrawGeofences();
                  nameController.clear();
                  radiusController.clear();
                  latController.clear();
                  lngController.clear();
                  gc.name.value = '';
                  gc.radius.value = 0;
                  gc.latitude.value = 0.0;
                  gc.longitude.value = 0.0;
                  if (currentGeofenceFill != null) {
                    try {
                      await map?.removeFill(currentGeofenceFill!);
                    } catch (e) {
                      print("Error removing fill: $e");
                    }
                    currentGeofenceFill = null;
                  }
                },
                icon: const Icon(Icons.add_location),
                label: const Text("Create Global Geofence"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
            const Divider(height: 32, thickness: 1.5),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueGrey[100]!,
                    Colors.blueGrey[50]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.blueGrey[700], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "Existing Geofences",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Obx(() => gc.globalFences.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.location_off, size: 48, color: Colors.blueGrey[300]),
                          const SizedBox(height: 12),
                          Text(
                            "No geofences created yet",
                            style: TextStyle(color: Colors.blueGrey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: gc.globalFences.length,
                    itemBuilder: (_, i) {
                      final g = gc.globalFences[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blueGrey[200]!),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[100],
                            child: Icon(Icons.location_on, color: Colors.blueGrey[700]),
                          ),
                          title: Text(
                            g["name"] ?? "Unnamed",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Radius: ${g["radius"]}m\nAssigned: ${g["assigned_users"] ?? 0} users",
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.timeline, color: Colors.blue, size: 20),
                                tooltip: "View Events",
                                onPressed: () => _showEvents(g["id"], g["name"] ?? "Geofence"),
                              ),
                              IconButton(
                                icon: const Icon(Icons.group, color: Colors.green, size: 20),
                                tooltip: "Manage Employees",
                                onPressed: () => _showEditEmployees(g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                tooltip: "Delete",
                                onPressed: () async {
                                  final confirm = await Get.dialog<bool>(
                                    AlertDialog(
                                      title: const Text("Delete Geofence"),
                                      content: Text("Are you sure you want to delete '${g["name"]}'?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Get.back(result: false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Get.back(result: true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await gc.deleteGlobalGeofence(g["id"]);
                                    await _loadAndDrawGeofences();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }
}