import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/special_employee_controller.dart';
import '../../routes/app_routes.dart';

// ================================================================
// SPECIAL EMPLOYEE DASHBOARD
// Persistent bottom nav — IndexedStack keeps pages alive.
// Every sub-page opens as full-screen route pushed on top of this,
// so back button always works and bottom nav stays visible.
// ================================================================
class SpecialEmployeeDashboard extends StatefulWidget {
  const SpecialEmployeeDashboard({super.key});
  @override
  State<SpecialEmployeeDashboard> createState() => _State();
}

class _State extends State<SpecialEmployeeDashboard> {
  final c = Get.find<SpecialEmployeeController>();

  static const _navy   = Color(0xFF1A237E);
  static const _navy2  = Color(0xFF283593);
  static const _bg     = Color(0xFFF1F5F9);
  static const _white  = Colors.white;
  static const _dark   = Color(0xFF0F172A);
  static const _muted  = Color(0xFF64748B);
  static const _green  = Color(0xFF16A34A);
  static const _red    = Color(0xFFDC2626);
  static const _blue   = Color(0xFF1D4ED8);
  static const _purple = Color(0xFF7C3AED);
  static const _amber  = Color(0xFFF59E0B);

  // current bottom nav selection
  final RxInt _navIdx = 0.obs;

  // All pages pushed via Get.toNamed so back button works
  void _onNav(int i) {
    if (i == _navIdx.value) return;
    switch (i) {
      case 0:
        _navIdx.value = 0;
        break;
      case 1:
        Get.toNamed(Routes.TRACKING_MAP);
        break;
      case 2:
        Get.toNamed(Routes.TRACK_RECORD,
            arguments: {"user_id": c.userId, "name": c.username});
        break;
      case 3:
        Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST);
        break;
      case 4:
        Get.toNamed(Routes.EMPLOYEE_PROFILE);
        break;
    }
  }

  void _confirmLogout() {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w800)),
      content: const Text("Logout? Active recording will be saved first."),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: Text("Cancel", style: TextStyle(color: _muted))),
        ElevatedButton(
          onPressed: () { Get.back(); c.logout(); },
          style: ElevatedButton.styleFrom(backgroundColor: _red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text("Logout", style: TextStyle(color: _white))),
      ],
    ));
  }

  void _showGeoPhotoDialog() {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.camera_alt, color: Colors.purple[700], size: 22),
        const SizedBox(width: 10),
        const Text("Geo-Tagged Photo",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Obx(() => Text(
            c.lat.value != null
                ? "📍 ${c.lat.value?.toStringAsFixed(5)}, ${c.lng.value?.toStringAsFixed(5)}"
                : "📍 Location not available",
            style: TextStyle(fontSize: 13, color: Colors.blueGrey[700]))),
        const SizedBox(height: 6),
        Obx(() => Text(
            "🔋 Battery: ${c.battery.value == -1 ? 'N/A' : '${c.battery.value}%'}",
            style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]))),
        const SizedBox(height: 12),
        Text("Photo will be stamped with location, battery & time.",
            style: TextStyle(fontSize: 11, color: Colors.blueGrey[500])),
      ]),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel")),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt, size: 16),
          label: const Text("Capture"),
          onPressed: () {
            Get.back();
            c.captureAndUploadPhoto();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: _homePage()),
      bottomNavigationBar: _bottomNav(),
    );
  }

  // ================================================================
  // HOME PAGE — scrollable, no overflow
  // ================================================================
  Widget _homePage() {
    return RefreshIndicator(
      onRefresh: () async {
        await c.loadControlStatus();
        await c.loadLatestLocation();
        await c.loadGeofences();
      },
      color: _navy,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(children: [
              _trackingHero(),
              const SizedBox(height: 12),
              _recordingCard(),
              const SizedBox(height: 12),
              _quickActions(),
              const SizedBox(height: 12),
              _shiftAndStats(),
              const SizedBox(height: 12),
              _locationCard(),
              const SizedBox(height: 12),
              _geofencePreview(),
              const SizedBox(height: 16),
            ]),
          ),
        ]),
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_navy, _navy2]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Row(children: [
        // Selfie
        Obx(() => GestureDetector(
          onTap: () => Get.toNamed(Routes.EMPLOYEE_PROFILE),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _white.withOpacity(0.5), width: 2),
              color: _white.withOpacity(0.18)),
            child: ClipOval(child: c.selfieUrl.value.isNotEmpty
                ? Image.network(c.selfieUrl.value, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, color: _white, size: 22))
                : const Icon(Icons.person, color: _white, size: 22)),
          ),
        )),
        const SizedBox(width: 10),

        // Name + badge
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              c.username.isNotEmpty ? "Hi, ${c.username}" : "Hi, Employee",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: _white),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _amber.withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield, color: _amber, size: 9),
              const SizedBox(width: 3),
              Text("SPECIAL", style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w800,
                  color: _amber, letterSpacing: 0.5)),
            ]),
          ),
        ])),

        // Online chip — only green when actually tracking
        Obx(() => _onlineChip(c.isOnline.value)),
        const SizedBox(width: 6),

        // Notifications
        Obx(() => GestureDetector(
          onTap: _showNotifs,
          child: Stack(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_outlined,
                    color: _white, size: 19)),
            if (c.notifications.isNotEmpty)
              Positioned(top: 5, right: 5, child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle))),
          ]),
        )),
        const SizedBox(width: 6),

        // Logout
        GestureDetector(
          onTap: _confirmLogout,
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withOpacity(0.4))),
            child: const Icon(Icons.logout, color: _white, size: 16))),
      ]),
    );
  }

  Widget _onlineChip(bool on) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: on ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: BoxDecoration(
              color: on ? _green : _red, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text(on ? "Online" : "Offline",
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: on ? _green : _red)),
    ]),
  );

  // ================================================================
  // TRACKING HERO — responsive, no fixed heights
  // ================================================================
  Widget _trackingHero() {
    return Obx(() {
      final locked = c.trackLocked.value;
      final on     = c.trackingOn.value;
      final colors = locked
          ? [const Color(0xFFB91C1C), const Color(0xFF991B1B)]
          : on ? [const Color(0xFF15803D), const Color(0xFF166534)]
              : [const Color(0xFF334155), const Color(0xFF1E293B)];

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: colors[0].withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: _white.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(
                  locked ? Icons.lock : on ? Icons.location_on : Icons.location_off,
                  color: _white, size: 24)),
            const Spacer(),
            if (locked) _lockBadge("Admin Locked"),
            c.recordingOn.value
                ? Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 5, height: 5,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      const Text("REC", style: TextStyle(
                          color: _white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ]))
                : const SizedBox.shrink(),
          ]),

          const SizedBox(height: 12),
          Text(locked ? "Tracking Locked ON"
              : on ? "Tracking Active" : "Tracking Inactive",
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _white)),
          const SizedBox(height: 3),
          Text(locked ? "Force-enabled by admin"
              : on ? "Your location is being shared"
                  : "Tap below to start sharing",
              style: TextStyle(fontSize: 12, color: _white.withOpacity(0.75))),

          const SizedBox(height: 14),

          // Stats row — wrap on narrow screens
          Wrap(spacing: 0, children: [
            _hStat("Status", locked ? "LOCKED" : on ? "ACTIVE" : "OFF"),
            _hDiv(),
            _hStat("Battery",
                c.battery.value == -1 ? "N/A" : "${c.battery.value}%"),
            _hDiv(),
            _hStat("Zones", "${c.geofences.length}"),
            _hDiv(),
            _hStat("Shift",
                c.workingSlot.value.isEmpty ? "—" : c.workingSlot.value),
          ]),

          const SizedBox(height: 14),

          // Toggle button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: locked ? null : c.toggleTracking,
              icon: Icon(
                  locked ? Icons.lock
                      : on ? Icons.stop_circle_outlined
                          : Icons.play_circle_outlined,
                  size: 20,
                  color: locked ? Colors.white54 : on ? _red : _green),
              label: Text(
                  locked ? "Locked by Admin"
                      : on ? "Stop Tracking" : "Start Tracking",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: locked ? Colors.white54 : on ? _red : _green)),
              style: ElevatedButton.styleFrom(
                backgroundColor: locked ? _white.withOpacity(0.1) : _white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: locked
                        ? BorderSide(color: _white.withOpacity(0.3))
                        : BorderSide.none)),
            ),
          ),
        ]),
      );
    });
  }

  Widget _hStat(String label, String value) => SizedBox(
    width: 70,
    child: Column(children: [
      Text(value, style: const TextStyle(
          color: _white, fontSize: 12, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(
          color: _white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _hDiv() => Container(
      width: 1, height: 28, color: _white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 6));

  Widget _lockBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: _white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _white.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock, color: _white, size: 9),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(
          color: _white, fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );

  // ================================================================
  // RECORDING CARD
  // ================================================================
  Widget _recordingCard() {
    return Obx(() {
      final on     = c.recordingOn.value;
      final locked = c.recLocked.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: on ? _purple.withOpacity(0.35) : const Color(0xFFE2E8F0),
              width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(
                  color: on ? _purple.withOpacity(0.1) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11)),
              child: Stack(alignment: Alignment.center, children: [
                Icon(on ? Icons.mic : Icons.mic_off,
                    color: on ? _purple : _muted, size: 21),
                if (on) Positioned(top: 5, right: 5, child: Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle))),
              ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Voice Recording", style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: _dark)),
            Text(locked ? "🔒 Locked ON by admin"
                : on ? "● Recording & uploading..." : "Recording is off",
                style: TextStyle(fontSize: 11,
                    color: on ? _purple : locked ? _red : _muted)),
          ])),
          if (locked)
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("LOCKED",
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                        color: _red)))
          else
            Switch(value: on, onChanged: (v) => c.toggleRecording(v),
                activeColor: _purple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      );
    });
  }

  // ================================================================
  // QUICK ACTIONS GRID
  // ================================================================
  Widget _quickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Quick Actions",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _dark)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _qaCard(Icons.map, "Live Map", _blue,
            () => Get.toNamed(Routes.TRACKING_MAP))),
        const SizedBox(width: 10),
        Expanded(child: _qaCard(Icons.camera_alt, "Geo Photo",
            Colors.purple[700]!, _showGeoPhotoDialog)),
        const SizedBox(width: 10),
        Expanded(child: _qaCard(Icons.timeline, "Track", Colors.orange[700]!,
            () => Get.toNamed(Routes.TRACK_RECORD,
                arguments: {"user_id": c.userId, "name": c.username}))),
        const SizedBox(width: 10),
        Expanded(child: _qaCard(Icons.fence, "Geofences", Colors.teal[700]!,
            () => Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST))),
      ]),
    ]);
  }

  Widget _qaCard(IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: _dark),
                textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  // ================================================================
  // SHIFT + STATS
  // ================================================================
  Widget _shiftAndStats() {
    return Obx(() => Column(children: [
      // Shift
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.schedule, color: _navy, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.workingSlot.value.isEmpty ? "No Shift Assigned"
                : c.slotLabel(c.workingSlot.value),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _dark),
                overflow: TextOverflow.ellipsis),
            const Text("Working Shift",
                style: TextStyle(fontSize: 10, color: _muted)),
          ])),
        ]),
      ),
      const SizedBox(height: 10),
      // Battery + Zones row
      Row(children: [
        Expanded(child: _miniStat(Icons.battery_charging_full, "Battery",
            c.battery.value == -1 ? "N/A" : "${c.battery.value}%",
            c.battery.value != -1 && c.battery.value < 25 ? _red : _green)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(Icons.location_on, "Geofences",
            "${c.geofences.length}", _purple)),
      ]),
    ]));
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 8),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
                fontSize: 9, color: _muted, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  // ================================================================
  // LOCATION CARD
  // ================================================================
  Widget _locationCard() {
    return Obx(() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.my_location, color: _blue, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Current Location",
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 13, color: _dark)),
            Text(c.lastUpdate.value.isNotEmpty
                ? "Updated: ${c.formatTime(c.lastUpdate.value)}"
                : "No update yet",
                style: const TextStyle(fontSize: 10, color: _muted),
                overflow: TextOverflow.ellipsis),
          ])),
          GestureDetector(
            onTap: () => Get.toNamed(Routes.TRACKING_MAP),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new, size: 11, color: _blue),
                const SizedBox(width: 3),
                Text("Map", style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _blue)),
              ]))),
        ]),
        const Divider(height: 14),
        Row(children: [
          Expanded(child: _locItem("Latitude",
              c.lat.value?.toStringAsFixed(6) ?? "—")),
          const SizedBox(width: 10),
          Expanded(child: _locItem("Longitude",
              c.lng.value?.toStringAsFixed(6) ?? "—")),
        ]),
      ]),
    ));
  }

  Widget _locItem(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: _muted, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _dark),
            overflow: TextOverflow.ellipsis),
      ]);

  // ================================================================
  // GEOFENCE PREVIEW
  // ================================================================
  Widget _geofencePreview() {
    return Obx(() {
      final list = c.geofences.take(3).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("My Geofences",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
          const Spacer(),
          GestureDetector(
            onTap: () => Get.toNamed(Routes.EMPLOYEE_GEOFENCE_LIST),
            child: Text("View All →",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: _navy))),
        ]),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
                color: _white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Center(child: Text("No geofences assigned",
                style: TextStyle(color: _muted, fontSize: 12))))
        else
          ...list.map((f) {
            final inside = f["is_inside"] == true || f["is_inside"] == 1;
            final dist   = f["_distance"] as double?;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _white, borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: inside
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFE2E8F0),
                    width: 1.5),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6, offset: const Offset(0, 2))]),
              child: Row(children: [
                Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: inside
                            ? _green.withOpacity(0.1)
                            : _red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(
                        inside ? Icons.check_circle_outline
                            : Icons.location_on_outlined,
                        color: inside ? _green : _red, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f["name"] ?? "Unnamed",
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 12, color: _dark),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(spacing: 4, children: [
                    _chip(inside ? "Inside" : "Outside",
                        inside ? _green : _red),
                    _chip("R: ${f['radius']}m", _muted),
                    if (dist != null) _chip(c.formatDistance(dist), _muted),
                  ]),
                ])),
              ]),
            );
          }),
      ]);
    });
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700, color: c)),
  );

  // ================================================================
  // BOTTOM NAV
  // ================================================================
  Widget _bottomNav() {
    const items = [
      _NavItem(Icons.home_rounded,        "Home"),
      _NavItem(Icons.map_rounded,         "Map"),
      _NavItem(Icons.timeline_rounded,    "Track"),
      _NavItem(Icons.location_on_rounded, "Zones"),
      _NavItem(Icons.person_rounded,      "Profile"),
    ];
    return Obx(() => Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, -3))]),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIdx.value == i;
              return GestureDetector(
                onTap: () => _onNav(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(width: 56, child: Column(
                  mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40, height: 30,
                    decoration: BoxDecoration(
                      color: active
                          ? _navy.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(items[i].icon, size: 20,
                        color: active ? _navy : _muted)),
                  const SizedBox(height: 2),
                  Text(items[i].label, style: TextStyle(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? _navy : _muted)),
                ])),
              );
            }),
          ),
        ),
      ),
    ));
  }

  // ================================================================
  // NOTIFICATIONS SHEET
  // ================================================================
  void _showNotifs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              const Text("Live Alerts", style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                  onPressed: () { c.notifications.clear(); Get.back(); },
                  child: Text("Clear", style: TextStyle(color: _navy))),
            ])),
          const Divider(height: 1),
          Expanded(child: Obx(() {
            if (c.notifications.isEmpty) {
              return Center(child: Text("No alerts yet",
                  style: TextStyle(color: _muted, fontSize: 13)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: c.notifications.length,
              itemBuilder: (_, i) {
                final n    = c.notifications[i];
                final type = n["type"] as String? ?? "";
                final bc   = type == "enter" ? _green
                    : type == "exit"    ? Colors.orange
                    : type == "battery" ? _red : _navy;
                return Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(9),
                    border: Border(left: BorderSide(color: bc, width: 3))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n["msg"] ?? "", style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12, color: _dark)),
                    Text(n["time"] ?? "",
                        style: TextStyle(fontSize: 10, color: _muted)),
                  ]),
                );
              },
            );
          })),
        ]),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}