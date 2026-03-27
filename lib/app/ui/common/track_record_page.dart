import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class TrackRecordPage extends StatefulWidget {
  const TrackRecordPage({super.key});

  @override
  State<TrackRecordPage> createState() => _TrackRecordPageState();
}

class _TrackRecordPageState extends State<TrackRecordPage> {
  MapplsMapController? mapController;
  IO.Socket? socket;

  late int userId;
  late String name;

  DateTime selectedDate = DateTime.now();

  // ================= TRACK HISTORY (SEGMENTS) =================
  List<RouteSegment> segments = [];
  RouteSegment? selectedSegment;
  
  List<Symbol> routeMarkers = [];
  Line? currentRouteLine;

  // ================= LIVE TRACKING =================
  Symbol? employeeMarker;
  Circle? liveCircle; // Outer pulsing circle for live employee
  LatLng? lastEmployeeLocation;
  DateTime? lastUpdateTime;
  List<LatLng> liveTrackPoints = [];
  Line? livePolyline;

  bool mapReady = false;
  bool pageDisposed = false;

  // ================= CAMERA FOLLOW =================
  bool followMarker = true;
  double followZoom = 18;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    final args = Get.arguments;
    userId = args["user_id"];
    name = args["name"];

    _loadLatestLocation();
    _loadTrack();
    _initSocket();
  }

  @override
  void dispose() {
    pageDisposed = true;
    socket?.disconnect();
    socket = null;
    mapController = null;
    super.dispose();
  }

  // ================= SOCKET =================
  void _initSocket() {
    socket = IO.io(
      ApiEndpoints.socketBase,
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );

    socket!.on("location_update", (data) async {
      if (pageDisposed || !mapReady) return;
      if (data["user_id"] != userId) return;

      final pos = LatLng(
        (data["latitude"] as num).toDouble(),
        (data["longitude"] as num).toDouble(),
      );

      lastEmployeeLocation = pos;
      lastUpdateTime = DateTime.parse(data["time"]);

      // Add to live track points
      if (liveTrackPoints.isEmpty || 
          _haversine(liveTrackPoints.last, pos) > 0.01) { // 10m threshold
        liveTrackPoints.add(pos);
      }

      if (mapController != null) {
        await _updateEmployeeMarker(pos);
        await _updateLivePolyline();

        // 🎥 AUTO FOLLOW CAMERA
        if (followMarker) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: pos,
                zoom: followZoom,
                tilt: 45,
                bearing: 0,
              ),
            ),
          );
        }
      }

    });

    socket!.connect();
  }

  // ================= LOAD LAST LOCATION =================
  Future<void> _loadLatestLocation() async {
    final res = await ApiService.get("${ApiEndpoints.latestLocation}/$userId");

    if (res != null && res["success"] == true) {
      lastUpdateTime = DateTime.parse(res["time"]);

      lastEmployeeLocation = LatLng(
        (res["latitude"] as num).toDouble(),
        (res["longitude"] as num).toDouble(),
      );

      // Initialize live track with last known position
      liveTrackPoints = [lastEmployeeLocation!];

      if (mapController != null) {
        await _updateEmployeeMarker(lastEmployeeLocation!);
        if (segments.isEmpty) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(lastEmployeeLocation!, followZoom),
          );
        }
      }
    }
  }

  // ================= EMPLOYEE MARKER (GOOGLE MAPS STYLE BLUE DOT) =================
  Future<void> _updateEmployeeMarker(LatLng pos) async {
  if (!mapReady || mapController == null || pageDisposed) return;

  try {
    if (employeeMarker == null) {
      employeeMarker = await mapController!.addSymbol(
        SymbolOptions(
          geometry: pos,
          iconSize: 1.1,
          iconColor: "#FFFFFF",
        ),
      );
    } else {
      await mapController!.updateSymbol(
        employeeMarker!,
        SymbolOptions(geometry: pos),
      );
    }

    // Live blue circle (Google Maps style)
    if (isOnline) {
      if (liveCircle == null) {
        liveCircle = await mapController!.addCircle(
          CircleOptions(
            geometry: pos,
            circleRadius: 8,
            circleColor: "#4285F4",
            circleOpacity: 1.0,
            circleStrokeWidth: 3,
            circleStrokeColor: "#FFFFFF",
          ),
        );
      } else {
        await mapController!.updateCircle(
          liveCircle!,
          CircleOptions(geometry: pos),
        );
      }
    }
  } catch (e) {
    debugPrint("⚠️ Marker update skipped: $e");
  }
}


  // ================= UPDATE LIVE POLYLINE (GREEN) =================
  Future<void> _updateLivePolyline() async {
    if (mapController == null || !isOnline) return;
    
    if (liveTrackPoints.length < 2) return;

    // Remove old live polyline
    if (livePolyline != null) {
      await mapController!.removeLine(livePolyline!);
    }

    // Draw new live polyline in GREEN
    livePolyline = await mapController!.addLine(
      LineOptions(
        geometry: liveTrackPoints,
        lineColor: "#4CAF50", // 🟢 Green for live tracking
        lineWidth: 6,
        lineOpacity: 0.9,
      ),
    );
  }

  // ================= LOAD TRACK HISTORY =================
  Future<void> _loadTrack() async {
    final date =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final res = await ApiService.get(
      "${ApiEndpoints.trackRecords}/$userId?date=$date",
    );

    if (res != null && res["success"] == true) {
      segments.clear();
      
      final segs = res["segments"] as List;
      
      for (int i = 0; i < segs.length; i++) {
        final points = (segs[i] as List).map((p) => 
          LatLng(p["lat"], p["lng"])
        ).toList();
        
        final times = (segs[i] as List).map((p) => p["time"] as String).toList();
        
        if (points.length >= 2) {
          segments.add(RouteSegment(
            index: i + 1,
            points: points,
            startTime: times.first,
            endTime: times.last,
            distance: _calculateDistance(points),
            duration: _calculateDuration(times.first, times.last),
          ));
        }
      }

      // 🎯 Auto-select LATEST (last) segment by default
      // BUT only if employee is NOT live
      if (segments.isNotEmpty && !isOnline) {
        selectedSegment = segments.last;
        if (mapController != null) {
          await _drawSelectedRoute();
        }
      } else if (segments.isNotEmpty) {
        // Set selected but don't draw if live
        selectedSegment = segments.last;
      }

      setState(() {});
    }
  }

  // ================= DRAW SELECTED ROUTE =================
  Future<void> _drawSelectedRoute() async {
    if (mapController == null || selectedSegment == null) return;

    // Clear previous route and markers
    if (currentRouteLine != null) {
      await mapController!.removeLine(currentRouteLine!);
    }
    for (var marker in routeMarkers) {
      await mapController!.removeSymbol(marker);
    }
    routeMarkers.clear();

    // Draw route polyline in BLUE
    currentRouteLine = await mapController!.addLine(
      LineOptions(
        geometry: selectedSegment!.points,
        lineColor: "#2196F3", // 🔵 Blue for historical route
        lineWidth: 6,
        lineOpacity: 0.85,
      ),
    );

    // Add start marker (ORANGE)
    final startMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: selectedSegment!.points.first,
        iconSize: 1.8,
        iconColor: "#FF9800", // 🟠 Orange
      ),
    );
    routeMarkers.add(startMarker);

    // Add end marker (RED)
    final endMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: selectedSegment!.points.last,
        iconSize: 1.8,
        iconColor: "#F44336", // 🔴 Red
      ),
    );
    routeMarkers.add(endMarker);

    // Auto-zoom to fit route with padding
    _fitRouteBounds(selectedSegment!.points);

    // Ensure employee marker is still visible
    if (lastEmployeeLocation != null) {
      await _updateEmployeeMarker(lastEmployeeLocation!);
    }

    // Redraw live polyline if employee is online
    if (isOnline && liveTrackPoints.length >= 2) {
      await _updateLivePolyline();
    }
  }

  // ================= FIT ROUTE BOUNDS =================
  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 50,
        top: 50,
        right: 50,
        bottom: 50,
      ),
    );
  }

  // ================= CALCULATE DISTANCE (KM) =================
  double _calculateDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversine(points[i], points[i + 1]);
    }
    return total;
  }

  double _haversine(LatLng p1, LatLng p2) {
    const R = 6371; // Earth radius in km
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * math.pi / 180) *
            math.cos(p2.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // ================= CALCULATE DURATION =================
  int _calculateDuration(String start, String end) {
    final s = TimeOfDay(
      hour: int.parse(start.split(":")[0]),
      minute: int.parse(start.split(":")[1]),
    );
    final e = TimeOfDay(
      hour: int.parse(end.split(":")[0]),
      minute: int.parse(end.split(":")[1]),
    );

    final startMin = s.hour * 60 + s.minute;
    final endMin = e.hour * 60 + e.minute;

    return endMin - startMin;
  }

  bool get isOnline {
    if (lastUpdateTime == null) return false;
    return DateTime.now().difference(lastUpdateTime!).inSeconds <= 30;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Track Records – $name"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: Icon(
          followMarker ? Icons.gps_fixed : Icons.gps_not_fixed,
        ),
        onPressed: () {
          setState(() => followMarker = !followMarker);
        },
      ),

      body: Stack(
        children: [
          MapplsMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 12,
            ),
            onMapCreated: (controller) async {
              mapController = controller;
              mapReady = true;
            
              if (pageDisposed) return;
            
              if (lastEmployeeLocation != null) {
                await _updateEmployeeMarker(lastEmployeeLocation!);
              }
            
              if (selectedSegment != null && !isOnline) {
                await _drawSelectedRoute();
              } else if (lastEmployeeLocation != null) {
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(lastEmployeeLocation!, followZoom),
                );
              }
            
              if (isOnline && liveTrackPoints.length >= 2) {
                await _updateLivePolyline();
              }
            },

          ),

          // ================= LIVE STATUS =================
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? "LIVE" : "OFFLINE",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= ROUTE SELECTOR DROPDOWN =================
          if (segments.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<RouteSegment>(
                  value: selectedSegment,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  items: segments.map((seg) {
                    return DropdownMenuItem(
                      value: seg,
                      child: Text(
                        "Trip ${seg.index}: ${seg.startTime.substring(0, 5)} - ${seg.endTime.substring(0, 5)} (${seg.duration}m)",
                        style: TextStyle(
                          fontWeight: selectedSegment == seg ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (seg) async {
                    setState(() => selectedSegment = seg);
                    await _drawSelectedRoute();
                  },
                ),
              ),
            ),

          // ================= ROUTE INFO CARD =================
          if (selectedSegment != null && currentRouteLine != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoChip(
                      icon: Icons.route,
                      label: "Distance",
                      value: "${selectedSegment!.distance.toStringAsFixed(2)} km",
                      color: Colors.blue,
                    ),
                    _InfoChip(
                      icon: Icons.access_time,
                      label: "Duration",
                      value: "${selectedSegment!.duration} min",
                      color: Colors.orange,
                    ),
                    _InfoChip(
                      icon: Icons.flag,
                      label: "Points",
                      value: "${selectedSegment!.points.length}",
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

          // ================= LIVE TRACKING INDICATOR =================
          if (isOnline && liveTrackPoints.length >= 2)
            Positioned(
              top: 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Live Track: ${liveTrackPoints.length} pts",
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= DATE PICKER =================
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      initialDate: selectedDate,
    );

    if (d != null) {
      setState(() {
        selectedDate = d;
        // Reset live tracking when changing dates
        liveTrackPoints.clear();
        if (lastEmployeeLocation != null) {
          liveTrackPoints.add(lastEmployeeLocation!);
        }
      });
      _loadTrack();
    }
  }
}

// ================= ROUTE SEGMENT MODEL =================
class RouteSegment {
  final int index;
  final List<LatLng> points;
  final String startTime;
  final String endTime;
  final double distance;
  final int duration;

  RouteSegment({
    required this.index,
    required this.points,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.duration,
  });
}

// ================= INFO CHIP WIDGET =================
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}