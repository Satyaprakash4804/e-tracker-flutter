import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/employee_controller.dart';

class EmployeeGeofenceListPage extends StatefulWidget {
  const EmployeeGeofenceListPage({super.key});

  @override
  State<EmployeeGeofenceListPage> createState() =>
      _EmployeeGeofenceListPageState();
}

class _EmployeeGeofenceListPageState extends State<EmployeeGeofenceListPage> {
  final EmployeeController c = Get.find<EmployeeController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.userId != 0) {
        c.loadGeofences();
      }
    });
  }

  // Distance calculation
  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
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
      if (km >= 10) {
        return "${km.toStringAsFixed(1)} km";
      } else {
        return "${km.toStringAsFixed(2)} km";
      }
    } else {
      return "${meters.toStringAsFixed(0)} m";
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) return "0s";

    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    List<String> parts = [];
    
    if (days > 0) parts.add("${days}d");
    if (hours > 0) parts.add("${hours}h");
    if (minutes > 0) parts.add("${minutes}m");
    if (secs > 0 || parts.isEmpty) parts.add("${secs}s");

    return parts.join(" ");
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return "—";
    try {
      final dt = DateTime.parse(dateTime.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return "Today at $hour:$minute";
      } else if (diff.inDays == 1) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return "Yesterday at $hour:$minute";
      } else if (diff.inDays < 7) {
        return "${diff.inDays} days ago";
      } else {
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year;
        return "$day/$month/$year";
      }
    } catch (e) {
      return dateTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    final isLargeScreen = size.width >= 900;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Get.offAllNamed('/employee-dashboard');
        }
        return false;
      },
      
      child: Scaffold(
    
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
              // Custom App Bar
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
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (Get.isOverlaysOpen) {
                            Get.back();
                            return;
                          }
                        
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Get.offAllNamed('/employee-dashboard');
                          }
                        },
                        
                        
                        
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "My Geofences",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Obx(() => Text(
                                "${c.fences.length} Geofence${c.fences.length != 1 ? 's' : ''} Assigned",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fence,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Obx(() {
                  if (c.loadingFences.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueGrey[700],
                      ),
                    );
                  }

                  if (c.fences.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fence,
                            size: isSmallScreen ? 64 : 80,
                            color: Colors.blueGrey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No geofences assigned",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              color: Colors.blueGrey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                      vertical: 16,
                    ),
                    physics: BouncingScrollPhysics(),
                    itemCount: c.fences.length,
                    itemBuilder: (_, index) {
                      final f = c.fences[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isLargeScreen ? 1200 : double.infinity,
                          ),
                          child: _geofenceCard(f, isSmallScreen),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),);
  }

  Widget _geofenceCard(Map f, bool isSmallScreen) {
    final bool inside = f["is_inside"] == true;
    final bool isGlobal = f["type"] == "global";
    final List events = f["events"] ?? [];
    final String? assignedAt = f["assigned_at"];

    final dist = (c.liveLat.value != 0 && c.liveLng.value != 0)
        ? _distance(
            c.liveLat.value,
            c.liveLng.value,
            f["latitude"],
            f["longitude"],
          )
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inside ? Colors.green[200]! : Colors.blueGrey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(isSmallScreen ? 14 : 16),
          childrenPadding: EdgeInsets.fromLTRB(
            isSmallScreen ? 14 : 16,
            0,
            isSmallScreen ? 14 : 16,
            isSmallScreen ? 14 : 16,
          ),
          leading: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: inside ? Colors.green[50] : Colors.red[50],
              shape: BoxShape.circle,
              border: Border.all(
                color: inside ? Colors.green[200]! : Colors.red[200]!,
                width: 2,
              ),
            ),
            child: Icon(
              inside ? Icons.check_circle : Icons.location_off,
              color: inside ? Colors.green[700] : Colors.red[700],
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  f["name"] ?? "Unnamed Geofence",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 17 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              _badge(
                isGlobal ? "GLOBAL" : "EMPLOYEE",
                isGlobal ? Colors.deepPurple : Colors.teal,
                isSmallScreen,
              ),
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: inside ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  inside ? "Inside Geofence" : "Outside Geofence",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: inside ? Colors.green[900] : Colors.red[900],
                  ),
                ),
              ],
            ),
          ),
          children: [
            // Geofence Details
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Geofence Details",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  SizedBox(height: 12),
                  _infoRow(
                    icon: Icons.location_on,
                    label: "Latitude",
                    value: "${f['latitude']}",
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.location_on,
                    label: "Longitude",
                    value: "${f['longitude']}",
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.radio_button_unchecked,
                    label: "Radius",
                    value: "${f['radius']} m",
                    isSmallScreen: isSmallScreen,
                  ),
                  if (assignedAt != null) ...[
                    SizedBox(height: 8),
                    _infoRow(
                      icon: Icons.calendar_today,
                      label: "Assigned",
                      value: _formatDateTime(assignedAt),
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ],
              ),
            ),

            // Distance Info
            if (dist != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.straighten,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Distance from Center",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _formatDistance(dist),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Last Activity
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Last Activity",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.login, size: 16, color: Colors.green[700]),
                                SizedBox(width: 6),
                                Text(
                                  "Entry",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11 : 12,
                                    color: Colors.blueGrey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDateTime(f["last_entry"]),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: Colors.blueGrey[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.orange[200],
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.logout, size: 16, color: Colors.red[700]),
                                SizedBox(width: 6),
                                Text(
                                  "Exit",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11 : 12,
                                    color: Colors.blueGrey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDateTime(f["last_exit"]),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: Colors.blueGrey[900],
                                fontWeight: FontWeight.w600,
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

            // Event History
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Event History",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[900],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${events.length} event${events.length != 1 ? 's' : ''}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (events.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              size: 40,
                              color: Colors.purple[300],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "No events recorded yet",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: events.take(5).map((e) {
                        return _eventTile(e, isSmallScreen);
                      }).toList(),
                    ),
                  if (events.length > 5)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          "+${events.length - 5} more events",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, bool isSmallScreen) {
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

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey[600]),
        SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            color: Colors.blueGrey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.blueGrey[900],
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _eventTile(Map e, bool isSmallScreen) {
    final int durationSeconds = e['duration_seconds'] ?? 0;
    final String formattedDuration = _formatDuration(durationSeconds);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.login, size: 14, color: Colors.green[700]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDateTime(e['entry_time']),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.logout, size: 14, color: Colors.red[700]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDateTime(e['exit_time']),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 14, color: Colors.blue[700]),
                SizedBox(width: 6),
                Text(
                  "Duration: $formattedDuration",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}