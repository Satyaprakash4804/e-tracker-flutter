import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/master_admin_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/geofence_controller.dart';
import '../../routes/app_routes.dart';
import '../../constants/api_endpoints.dart';

class MasterAdminDashboard extends StatefulWidget {
  const MasterAdminDashboard({super.key});
  @override
  State<MasterAdminDashboard> createState() => _MasterAdminDashboardState();
}

class _MasterAdminDashboardState extends State<MasterAdminDashboard>
    with SingleTickerProviderStateMixin {

  final c = Get.find<MasterAdminController>();

  final RxString _roleFilter = 'all'.obs;
  final _searchCtrl = TextEditingController();
  final RxString _searchQ = ''.obs;
  final RxInt _navIdx = 0.obs;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        const roles = ['all', 'admin', 'employee', 'special_employee'];
        _roleFilter.value = roles[_tabCtrl.index];
      }
    });
    if (!Get.isRegistered<AdminController>())   Get.put(AdminController());
    if (!Get.isRegistered<GeofenceController>()) Get.put(GeofenceController());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────
  bool _isOnline(Map u) {
    final last = u["last_update"];
    if (last == null || last.toString().isEmpty) return false;
    try {
      return DateTime.now().toUtc()
          .difference(DateTime.parse(last).toUtc()).inSeconds <= 30;
    } catch (_) { return false; }
  }

  String _fmt(String? ts) {
    if (ts == null || ts.isEmpty) return "Never";
    try {
      final dt = DateTime.parse(ts).toLocal();
      return "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year} "
          "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (_) { return "Invalid"; }
  }

  String _slot(String? s) => const {
    '9-5': '09:00–17:00 Day',
    '5-1': '17:00–01:00 Eve',
    '1-9': '01:00–09:00 Night',
  }[s] ?? 'Not Set';

  String? _imgUrl(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return "${ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api$'), '')}$p";
  }

  List<Map<String, dynamic>> get _filtered {
    final role = _roleFilter.value;
    final q = _searchQ.value.toLowerCase();
    var list = role == 'all'
        ? c.allUsers.where((u) => u["role"] != "master_admin").toList()
        : c.allUsers.where((u) => u["role"] == role).toList();
    if (q.isNotEmpty) {
      list = list.where((u) =>
          (u["username"] ?? "").toLowerCase().contains(q) ||
          (u["full_name"] ?? "").toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _openGeofence(Map u) {
    final ac = Get.find<AdminController>();
    if (!ac.employees.any((e) => e["id"] == u["id"])) {
      ac.employees.add(Map<String, dynamic>.from(u));
    }
    Get.toNamed(Routes.ADMIN_GEOFENCE, arguments: u["id"]);
  }

  // ── Responsive breakpoints ───────────────────────────────────
  bool _isSmall(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;
  bool _isMedium(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return w >= 600 && w < 900;
  }
  bool _isLarge(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 900;

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSmall  = _isSmall(context);
      final isMedium = _isMedium(context);
      final isLarge  = _isLarge(context);

      Widget page;
      bool showFab = false;
      switch (_navIdx.value) {
        case 0:
          page = _usersPage(isSmall, isMedium, isLarge);
          showFab = true;
          break;
        case 1:
          page = _specialPage(isSmall);
          break;
        case 2:
          page = _recordingsPage(isSmall);
          break;
        case 3:
          page = _settingsPage(isSmall);
          break;
        default:
          page = _usersPage(isSmall, isMedium, isLarge);
          showFab = true;
      }

      return Scaffold(
        drawer: _navIdx.value == 0 ? _drawer(isSmall) : null,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blueGrey[50]!, Colors.blueGrey[100]!],
            ),
          ),
          child: SafeArea(child: page),
        ),
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                onPressed: () => _showCreateSheet(context),
                backgroundColor: Colors.blueGrey[700],
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: Text(
                  isSmall ? "Add" : "Add User",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        bottomNavigationBar: _bottomNav(),
      );
    });
  }

  // ================================================================
  // BOTTOM NAV
  // ================================================================
  Widget _bottomNav() {
    const items = [
      {'icon': Icons.dashboard,  'label': 'Dashboard'},
      {'icon': Icons.shield,     'label': 'Special'},
      {'icon': Icons.mic,        'label': 'Recordings'},
      {'icon': Icons.public,     'label': 'Geofence'},
      {'icon': Icons.settings,   'label': 'Settings'},
    ];
    return Obx(() => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 16, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIdx.value == i;
              return GestureDetector(
                onTap: () {
                  if (i == 3) {
                    Get.toNamed(Routes.ADMIN_GLOBAL_GEOFENCE);
                  } else {
                    _navIdx.value = i;
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44, height: 32,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.blueGrey[700]!.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          items[i]['icon'] as IconData,
                          size: 20,
                          color: active
                              ? Colors.blueGrey[700]
                              : Colors.blueGrey[400],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.blueGrey[700]
                              : Colors.blueGrey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ));
  }

  // ================================================================
  // DRAWER
  // ================================================================
  Widget _drawer(bool isSmall) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blueGrey[50]!, Colors.white],
          ),
        ),
        child: Column(children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20, left: 20, right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.blueGrey[800]!, Colors.blueGrey[700]!],
              ),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: Icon(Icons.admin_panel_settings,
                    size: isSmall ? 48 : 56, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text("Master Admin",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star, color: Colors.amber, size: 13),
                  SizedBox(width: 4),
                  Text("MASTER ADMIN",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                          letterSpacing: 0.5)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _dItem(Icons.dashboard, "Dashboard", () => Get.back()),
                  _dItem(Icons.person_add, "Create User", () {
                    Get.back();
                    _showCreateSheet(context);
                  }),
                  _dItem(Icons.shield, "Special Employees", () {
                    Get.back();
                    _navIdx.value = 1;
                  }),
                  _dItem(Icons.mic, "Recordings", () {
                    Get.back();
                    _navIdx.value = 2;
                  }),
                  _dItem(Icons.public, "Global Geofence", () {
                    Get.back();
                    Get.toNamed(Routes.ADMIN_GLOBAL_GEOFENCE);
                  }),
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Text("Alert Settings",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[600],
                            letterSpacing: 0.5)),
                  ),
                  Obx(() => _dSwitch(
                      Icons.notifications_active,
                      "Geofence Alerts",
                      c.geofenceAlertOn.value,
                      c.toggleGeofenceAlert)),
                  Obx(() => _dSwitch(Icons.battery_alert, "Battery Alerts",
                      c.batteryAlertOn.value, c.toggleBatteryAlert)),
                ]),
          ),
          const Divider(height: 1),
          _dItem(Icons.logout, "Sign Out", () {
            GetStorage().erase();
            Get.offAllNamed(Routes.LOGIN);
          }, color: Colors.red),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _dItem(IconData icon, String title, VoidCallback onTap,
          {Color? color}) =>
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      );

  Widget _dSwitch(IconData icon, String title, bool value,
          Function(bool) onChanged) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey[200]!)),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.blueGrey[700], size: 22),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[900])),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blueGrey[700],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      );

  // ================================================================
  // PAGE 0: USERS DASHBOARD
  // ================================================================
  Widget _usersPage(bool isSmall, bool isMedium, bool isLarge) {
    return Column(children: [
      // ── App Bar ──
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 16 : 24,
            vertical: isSmall ? 14 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey[700]!, Colors.blueGrey[600]!],
          ),
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32)),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Row(children: [
            Builder(builder: (ctx) => Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer()),
            )),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Master Admin",
                      style: TextStyle(
                          fontSize: isSmall ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                  Text("E-Tracker Control Panel",
                      style: TextStyle(
                          fontSize: isSmall ? 11 : 13,
                          color: Colors.white.withOpacity(0.9))),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, color: Colors.amber, size: 12),
                SizedBox(width: 4),
                Text("MASTER",
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        letterSpacing: 0.8)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          // ── Stats Row ──
          Obx(() {
            final total  = c.allUsers.where((u) => u["role"] != "master_admin").length;
            final online = c.allUsers.where(_isOnline).length;
            final sp     = c.specialEmployees.length;
            final lowBat = c.allUsers.where((u) {
              final b = u["battery"] as int? ?? -1;
              return b != -1 && b < 25;
            }).length;
            return Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 12 : 16,
                  vertical: isSmall ? 10 : 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("Total",   total.toString(),  Icons.people,       Colors.white, isSmall),
                  _vd(),
                  _stat("Online",  online.toString(), Icons.wifi,         Colors.white, isSmall),
                  _vd(),
                  _stat("Special", sp.toString(),     Icons.shield,       Colors.white, isSmall),
                  _vd(),
                  _stat("Low Bat", lowBat.toString(), Icons.battery_alert,
                      lowBat > 0 ? Colors.red[200]! : Colors.white, isSmall),
                ],
              ),
            );
          }),
        ]),
      ),

      // ── Role Tabs ──
      _roleTabs(isSmall),

      // ── Search ──
      Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 12 : (isMedium ? 24 : 32),
            vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey[200]!, width: 1.5),
            boxShadow: [BoxShadow(
                color: Colors.blueGrey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => _searchQ.value = v,
            style: TextStyle(fontSize: isSmall ? 13 : 14),
            decoration: InputDecoration(
              hintText: "Search users…",
              hintStyle:
                  TextStyle(color: Colors.blueGrey[400], fontSize: isSmall ? 13 : 14),
              prefixIcon: Icon(Icons.search, color: Colors.blueGrey[600], size: isSmall ? 20 : 22),
              suffixIcon: Obx(() => _searchQ.value.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: Colors.blueGrey[600], size: isSmall ? 18 : 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        _searchQ.value = '';
                      })
                  : const SizedBox.shrink()),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: isSmall ? 12 : 16),
            ),
          ),
        ),
      ),

      // ── User List ──
      Expanded(child: Obx(() {
        if (c.loading.value) {
          return Center(
              child: CircularProgressIndicator(color: Colors.blueGrey[700]));
        }
        final list = _filtered;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: isSmall ? 56 : 72, color: Colors.blueGrey[300]),
                const SizedBox(height: 16),
                Text("No users found",
                    style: TextStyle(
                        fontSize: isSmall ? 14 : 16,
                        color: Colors.blueGrey[500],
                        fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            left: isSmall ? 12 : (isMedium ? 24 : 32),
            right: isSmall ? 12 : (isMedium ? 24 : 32),
            bottom: 100,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: isLarge ? 900 : double.infinity),
              child: _userCard(list[i], isSmall, isMedium),
            ),
          ),
        );
      })),
    ]);
  }

  Widget _roleTabs(bool isSmall) {
    return Obx(() {
      final all = c.allUsers.where((u) => u["role"] != "master_admin").length;
      return Container(
        margin: EdgeInsets.fromLTRB(isSmall ? 12 : 16, 12, isSmall ? 12 : 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
              color: Colors.blueGrey[700],
              borderRadius: BorderRadius.circular(10)),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blueGrey[600],
          labelStyle: TextStyle(
              fontSize: isSmall ? 10 : 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              TextStyle(fontSize: isSmall ? 9 : 11),
          indicatorPadding: const EdgeInsets.all(4),
          tabs: [
            Tab(text: isSmall ? "All\n$all" : "All ($all)"),
            Tab(text: isSmall ? "Admin\n${c.admins.length}" : "Admin (${c.admins.length})"),
            Tab(text: isSmall ? "Emp\n${c.employees.length}" : "Emp (${c.employees.length})"),
            Tab(text: isSmall ? "Spec\n${c.specialEmployees.length}" : "Special (${c.specialEmployees.length})"),
          ],
        ),
      );
    });
  }

  // ================================================================
  // USER CARD
  // ================================================================
  Widget _userCard(Map<String, dynamic> u, bool isSmall, bool isMedium) {
    final online  = _isOnline(u);
    final role    = u["role"] as String? ?? "employee";
    final isSP    = role == "special_employee";
    final isEmp   = role == "employee" || isSP;
    final bat     = u["battery"] as int? ?? -1;
    final lowBat  = bat != -1 && bat < 25;
    final reg     = u["registration_completed"] == 1;
    final img     = _imgUrl(u["selfie_path"]);
    final hasShift= (u["working_hours_slot"] as String? ?? "").isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: online ? Colors.green[200]! : Colors.blueGrey[200]!,
            width: 2),
        boxShadow: [BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // ── Header ──
        Container(
          padding: EdgeInsets.all(isSmall ? 12 : 16),
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
                topRight: Radius.circular(18)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: isEmp
                  ? () => Get.toNamed(Routes.ADMIN_EMPLOYEE_PROFILE,
                      arguments: u["id"])
                  : null,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: online
                            ? Colors.green
                            : Colors.blueGrey[400]!,
                        width: 3),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: isSmall ? 24 : 30,
                    backgroundColor: Colors.blueGrey[200],
                    backgroundImage:
                        img != null ? NetworkImage(img) : null,
                    child: img == null
                        ? Icon(Icons.person,
                            color: Colors.white,
                            size: isSmall ? 22 : 28)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: online ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u["username"] ?? "Unknown",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmall ? 14 : 16,
                            color: Colors.blueGrey[900])),
                    const SizedBox(height: 5),
                    Wrap(spacing: 5, runSpacing: 3, children: [
                      _badge(online ? "ONLINE" : "OFFLINE",
                          online ? Colors.green : Colors.red, isSmall),
                      _badge(_roleLabel(role), _roleColor(role), isSmall),
                      _badge(reg ? "REGISTERED" : "PENDING",
                          reg ? Colors.blue : Colors.orange, isSmall),
                    ]),
                  ]),
            ),
          ]),
        ),

        // ── Body (employees only) ──
        if (isEmp)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 16,
                vertical: isSmall ? 10 : 14),
            child: isMedium || !isSmall
                // 2-column grid on medium/large
                ? Column(children: [
                    Row(children: [
                      Expanded(child: _infoRow(
                          Icons.location_on_outlined, "Location",
                          u["lat"] != null
                              ? "${u['lat']}, ${u['lng']}"
                              : "Not available",
                          isSmall)),
                      const SizedBox(width: 10),
                      Expanded(child: _infoRow(
                          Icons.access_time, "Last Update",
                          _fmt(u["last_update"]), isSmall)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _infoRow(
                          Icons.battery_charging_full, "Battery",
                          bat == -1 ? "N/A" : "$bat%", isSmall,
                          valueColor:
                              lowBat ? Colors.red : Colors.green)),
                      const SizedBox(width: 10),
                      Expanded(child: _infoRow(
                          Icons.schedule, "Shift",
                          _slot(u["working_hours_slot"]), isSmall)),
                    ]),
                  ])
                // single column on small
                : Column(children: [
                    _infoRow(Icons.location_on_outlined, "Location",
                        u["lat"] != null
                            ? "${u['lat']}, ${u['lng']}"
                            : "Not available",
                        isSmall),
                    const SizedBox(height: 8),
                    _infoRow(Icons.access_time, "Last Update",
                        _fmt(u["last_update"]), isSmall),
                    const SizedBox(height: 8),
                    _infoRow(Icons.battery_charging_full, "Battery",
                        bat == -1 ? "N/A" : "$bat%", isSmall,
                        valueColor: lowBat ? Colors.red : Colors.green),
                    const SizedBox(height: 8),
                    _infoRow(Icons.schedule, "Shift",
                        _slot(u["working_hours_slot"]), isSmall),
                  ]),
          ),

        // ── Actions ──
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 8 : 12,
              vertical: isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18)),
          ),
          child: Wrap(
            spacing: isSmall ? 5 : 7,
            runSpacing: isSmall ? 5 : 7,
            alignment: WrapAlignment.center,
            children: [
              if (isEmp) ...[
                _actBtn("Profile", Icons.person,
                    Colors.blueGrey[700]!, isSmall,
                    () => Get.toNamed(Routes.ADMIN_EMPLOYEE_PROFILE,
                        arguments: u["id"])),
                _actBtn("Track", Icons.timeline,
                    Colors.blue[700]!, isSmall,
                    () => Get.toNamed(Routes.TRACK_RECORD,
                        arguments: {
                          "user_id": u["id"],
                          "name": u["username"]
                        })),
                _actBtn("Geo", Icons.map, Colors.green[700]!, isSmall,
                    () => _openGeofence(u)),
                if (!hasShift)
                  _actBtn("Set Shift", Icons.schedule,
                      Colors.teal[700]!, isSmall,
                      () => _showHoursSheet(context, u)),
              ],
              if (isSP) ...[
                _actBtn("Force", Icons.shield,
                    Colors.purple[700]!, isSmall,
                    () => _showForceSheet(context, u)),
                _actBtn("Recs", Icons.mic,
                    Colors.orange[700]!, isSmall,
                    () => _showRecordingsSheet(context, u)),
              ],
              _actBtn("Delete", Icons.delete,
                  Colors.red[700]!, isSmall,
                  () => _confirmDelete(u)),
            ],
          ),
        ),
      ]),
    );
  }

  String _roleLabel(String? r) => r == 'admin'
      ? 'Admin'
      : r == 'special_employee'
          ? 'Special'
          : 'Employee';

  Color _roleColor(String? r) => r == 'admin'
      ? Colors.blue[700]!
      : r == 'special_employee'
          ? Colors.purple[700]!
          : Colors.green[700]!;

  Widget _badge(String text, Color color, bool isSmall) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 6 : 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Text(text,
            style: TextStyle(
                fontSize: isSmall ? 9 : 11,
                fontWeight: FontWeight.bold,
                color: color)),
      );

  Widget _infoRow(IconData icon, String label, String value, bool isSmall,
          {Color? valueColor}) =>
      Row(children: [
        Container(
          padding: EdgeInsets.all(isSmall ? 6 : 8),
          decoration: BoxDecoration(
              color: Colors.blueGrey[100],
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: isSmall ? 15 : 18, color: Colors.blueGrey[700]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: isSmall ? 10 : 12,
                    color: Colors.blueGrey[600],
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: isSmall ? 12 : 13,
                    color: valueColor ?? Colors.blueGrey[900],
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);

  Widget _actBtn(String label, IconData icon, Color color, bool isSmall,
          VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 9 : 13, vertical: isSmall ? 7 : 9),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: isSmall ? 15 : 17, color: color),
            if (!isSmall) ...[
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ]),
        ),
      );

  Widget _stat(
          String label, String value, IconData icon, Color color, bool isSmall) =>
      Column(children: [
        Icon(icon, color: color, size: isSmall ? 16 : 20),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: isSmall ? 13 : 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmall ? 9 : 10,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _vd() => Container(
      width: 1, height: 28, color: Colors.white.withOpacity(0.3));

  // ================================================================
  // PAGE 1: SPECIAL EMPLOYEES
  // ================================================================
  Widget _buildHeader(String title, String sub, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 16 : 24,
          vertical: isSmall ? 12 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey[700]!, Colors.blueGrey[600]!],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28)),
        boxShadow: [BoxShadow(
            color: Colors.blueGrey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => _navIdx.value = 0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: isSmall ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85))),
          ]),
        ),
      ]),
    );
  }

  Widget _specialPage(bool isSmall) {
    return Column(children: [
      _buildHeader(
          "Special Employees", "Force controls & recordings", isSmall),
      Expanded(child: Obx(() {
        final list = c.specialEmployees;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: isSmall ? 56 : 72, color: Colors.blueGrey[300]),
                const SizedBox(height: 12),
                Text("No special employees",
                    style: TextStyle(
                        fontSize: isSmall ? 14 : 16,
                        color: Colors.blueGrey[500])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : 16, 16, isSmall ? 12 : 16, 100),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _userCard(list[i], isSmall, !isSmall),
        );
      })),
    ]);
  }

  // ================================================================
  // PAGE 2: RECORDINGS
  // ================================================================
  Widget _recordingsPage(bool isSmall) {
    return Column(children: [
      _buildHeader(
          "Voice Recordings", "All special employee recordings", isSmall),
      Expanded(child: Obx(() {
        final sps = c.specialEmployees;
        if (sps.isEmpty) {
          return Center(
              child: Text("No special employees",
                  style: TextStyle(color: Colors.blueGrey[500])));
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : 16, 16, isSmall ? 12 : 16, 100),
          itemCount: sps.length,
          itemBuilder: (_, i) => _empRecSection(sps[i], isSmall),
        );
      })),
    ]);
  }

  Widget _empRecSection(Map<String, dynamic> u, bool isSmall) {
    final img = _imgUrl(u["selfie_path"]);
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey[200]!, width: 2),
        boxShadow: [BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(isSmall ? 12 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.blueGrey[50]!, Colors.blueGrey[100]!]),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: isSmall ? 18 : 22,
              backgroundColor: Colors.blueGrey[200],
              backgroundImage:
                  img != null ? NetworkImage(img) : null,
              child: img == null
                  ? Icon(Icons.person, color: Colors.white,
                      size: isSmall ? 16 : 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u["username"] ?? "?",
                        style: TextStyle(
                            color: Colors.blueGrey[900],
                            fontSize: isSmall ? 13 : 15,
                            fontWeight: FontWeight.w700)),
                    Text(_slot(u["working_hours_slot"]),
                        style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontSize: isSmall ? 10 : 11)),
                  ]),
            ),
            InkWell(
              onTap: () => _showRecordingsSheet(context, u),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 12,
                    vertical: isSmall ? 6 : 8),
                decoration: BoxDecoration(
                    color: Colors.orange[700]!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic, color: Colors.orange[700],
                      size: isSmall ? 14 : 16),
                  const SizedBox(width: 5),
                  Text("View All",
                      style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: isSmall ? 11 : 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        _RecPreview(
            userId: u["id"] as int,
            controller: c,
            baseUrl: ApiEndpoints.baseUrl),
      ]),
    );
  }

  // ================================================================
  // PAGE 3: SETTINGS
  // ================================================================
  Widget _settingsPage(bool isSmall) {
    return Column(children: [
      _buildHeader("Settings", "Alerts & preferences", isSmall),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : 16, 20, isSmall ? 12 : 16, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sLabel("Alert Settings"),
                    const SizedBox(height: 10),
                    Obx(() => _toggleTile(
                        Icons.notifications_active,
                        "Geofence Alerts",
                        "Notify on geofence enter/exit",
                        c.geofenceAlertOn.value,
                        c.toggleGeofenceAlert)),
                    const SizedBox(height: 10),
                    Obx(() => _toggleTile(
                        Icons.battery_alert,
                        "Battery Alerts",
                        "Notify when battery < 25%",
                        c.batteryAlertOn.value,
                        c.toggleBatteryAlert)),
                    const SizedBox(height: 24),
                    _sLabel("Quick Actions"),
                    const SizedBox(height: 10),
                    _settBtn("Create New User", Icons.person_add,
                        Colors.blueGrey[700]!,
                        () => _showCreateSheet(context)),
                    const SizedBox(height: 10),
                    _settBtn("Refresh All Data", Icons.refresh,
                        Colors.blue[700]!, c.loadUsers),
                    const SizedBox(height: 24),
                    _sLabel("Account"),
                    const SizedBox(height: 10),
                    _settBtn("Sign Out", Icons.logout, Colors.red, () {
                      GetStorage().erase();
                      Get.offAllNamed(Routes.LOGIN);
                    }),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _sLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: TextStyle(
                color: Colors.blueGrey[700],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _toggleTile(IconData icon, String title, String desc, bool value,
          Function(bool) onChanged) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey[200]!),
            boxShadow: [BoxShadow(
                color: Colors.blueGrey.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))]),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.blueGrey[700], size: 22),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[900])),
          subtitle: Text(desc,
              style: TextStyle(
                  color: Colors.blueGrey[500], fontSize: 11)),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blueGrey[700],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      );

  Widget _settBtn(String label, IconData icon, Color color,
          VoidCallback onTap) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[900])),
        trailing:
            Icon(Icons.chevron_right, color: Colors.blueGrey[400]),
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blueGrey[200]!)),
        tileColor: Colors.white,
      );

  // ================================================================
  // CONFIRM DELETE  — FIXED: () => Get.back()
  // ================================================================
  void _confirmDelete(Map u) {
    Get.dialog(
      AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete User",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            "Delete \"${u['username']}\"? Cannot be undone.",
            style: TextStyle(color: Colors.blueGrey[700])),
        actions: [
          TextButton(
            // ✅ FIXED
            onPressed: () => Get.back(),
            child: Text("Cancel",
                style: TextStyle(color: Colors.blueGrey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // ✅ FIXED
              c.deleteUser(u["id"]);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text("Delete",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // CREATE USER SHEET  — FIXED context + Get.back()
  // ================================================================
  InputDecoration _iDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        prefixIcon: Icon(icon, color: Colors.blueGrey[600]),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey[200]!, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey[600]!, width: 2)),
        filled: true,
        fillColor: Colors.blueGrey[50],
      );

  void _showCreateSheet(BuildContext ctx) {
    final unCtrl   = TextEditingController();
    final pwCtrl   = TextEditingController();
    String role    = 'employee';
    String slot    = '';
    bool showPw    = false;
    final fk       = GlobalKey<FormState>();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ✅ FIXED: renamed inner context to sheetCtx to avoid shadowing 'c'
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: fk,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.blueGrey[200],
                              borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.person_add,
                            color: Colors.amber[700]),
                      ),
                      const SizedBox(width: 12),
                      Text("Create New User",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900])),
                    ]),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: unCtrl,
                      decoration: _iDeco("Username", Icons.person_outline),
                      validator: (v) =>
                          (v?.length ?? 0) < 3 ? "Min 3 chars" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: pwCtrl,
                      obscureText: !showPw,
                      decoration: _iDeco("Password", Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              showPw
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.blueGrey[600]),
                          onPressed: () =>
                              ss(() => showPw = !showPw),
                        ),
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) < 6 ? "Min 6 chars" : null,
                    ),
                    const SizedBox(height: 16),

                    Text("Role",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey[800])),
                    const SizedBox(height: 10),
                    Row(children: [
                      _roleChip("admin", "Admin",
                          Icons.admin_panel_settings, role,
                          (v) => ss(() {
                                role = v;
                                slot = '';
                              })),
                      const SizedBox(width: 8),
                      _roleChip("employee", "Employee", Icons.badge,
                          role,
                          (v) => ss(() {
                                role = v;
                                slot = '';
                              })),
                      const SizedBox(width: 8),
                      _roleChip("special_employee", "Special",
                          Icons.shield, role,
                          (v) => ss(() {
                                role = v;
                                slot = '';
                              })),
                    ]),

                    if (role == 'employee' ||
                        role == 'special_employee') ...[
                      const SizedBox(height: 16),
                      Text("Working Hours Slot",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey[800])),
                      const SizedBox(height: 10),
                      Row(children: [
                        _slotChip('9-5', '09:00–17:00', 'Day', slot,
                            (v) => ss(() => slot = v)),
                        const SizedBox(width: 8),
                        _slotChip('5-1', '17:00–01:00', 'Eve', slot,
                            (v) => ss(() => slot = v)),
                        const SizedBox(width: 8),
                        _slotChip('1-9', '01:00–09:00', 'Night', slot,
                            (v) => ss(() => slot = v)),
                      ]),
                    ],

                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          // ✅ FIXED
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey[700],
                              side: BorderSide(
                                  color: Colors.blueGrey[300]!),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Obx(() => ElevatedButton(
                          onPressed: c.loadingCreate.value
                              ? null
                              : () {
                                  if (!fk.currentState!.validate())
                                    return;
                                  c.createUser(
                                      username: unCtrl.text.trim(),
                                      password: pwCtrl.text.trim(),
                                      role: role,
                                      workingHoursSlot: slot.isEmpty
                                          ? null
                                          : slot);
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                          child: c.loadingCreate.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text("Create User",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                        )),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String val, String label, IconData icon, String cur,
      Function(String) onTap) {
    final active = cur == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.blueGrey[700]!.withOpacity(0.15)
                : Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active
                    ? Colors.blueGrey[700]!
                    : Colors.blueGrey[200]!,
                width: 1.5),
          ),
          child: Column(children: [
            Icon(icon,
                size: 18,
                color:
                    active ? Colors.blueGrey[700] : Colors.blueGrey[400]),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active
                        ? Colors.blueGrey[700]
                        : Colors.blueGrey[500])),
          ]),
        ),
      ),
    );
  }

  Widget _slotChip(String val, String time, String label, String cur,
      Function(String) onTap) {
    final active = cur == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.blue[50] : Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active
                    ? Colors.blue[700]!
                    : Colors.blueGrey[200]!,
                width: active ? 2 : 1.5),
          ),
          child: Column(children: [
            Text(time,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: active
                        ? Colors.blue[800]
                        : Colors.blueGrey[700])),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: active
                        ? Colors.blue[600]
                        : Colors.blueGrey[500])),
          ]),
        ),
      ),
    );
  }

  // ================================================================
  // WORKING HOURS SHEET  — FIXED: Navigator.of(ctx).pop()
  // ================================================================
  void _showHoursSheet(BuildContext ctx, Map u) {
    final existing = u["working_hours_slot"] as String? ?? "";
    if (existing.isNotEmpty) {
      Get.snackbar("Locked",
          "Shift already set to '${_slot(existing)}'. Cannot be changed.",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    String sel = '';
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, ss) => Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.blueGrey[200],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Set Working Hours",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900])),
            Text("For: ${u['username']}",
                style:
                    TextStyle(fontSize: 13, color: Colors.blueGrey[600])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(children: [
                Icon(Icons.lock, color: Colors.amber[700], size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      "⚠️ Once set, working hours CANNOT be changed.",
                      style: TextStyle(
                          color: Colors.amber[800], fontSize: 11)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _slotChip('9-5', '09:00–17:00', 'Day', sel,
                  (v) => ss(() => sel = v)),
              const SizedBox(width: 8),
              _slotChip('5-1', '17:00–01:00', 'Eve', sel,
                  (v) => ss(() => sel = v)),
              const SizedBox(width: 8),
              _slotChip('1-9', '01:00–09:00', 'Night', sel,
                  (v) => ss(() => sel = v)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (sel.isEmpty) {
                    Get.snackbar("Error", "Please select a slot",
                        snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  // ✅ FIXED: use Navigator to avoid context issues
                  Navigator.of(sheetCtx2).pop();
                  c.setWorkingHours(userId: u["id"], slot: sel);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text("Save (permanent)",
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ================================================================
  // FORCE CONTROLS SHEET  — FIXED: pre-fetch + () => Get.back()
  // ================================================================
  void _showForceSheet(BuildContext ctx, Map u) {
    bool trackOn     = false;
    bool recOn       = false;
    bool loadingInit = true;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, ss) {
          // ✅ FIXED: only fetch once when loadingInit is true
          if (loadingInit) {
            loadingInit = false; // prevent re-fetch on rebuild
            Future.microtask(() async {
              final data = await c.getControlStatus(u["id"]);
              if (data != null && data["success"] == true) {
                ss(() {
                  trackOn =
                      data["tracking"]?["effective"] == true;
                  recOn =
                      data["recording"]?["effective"] == true;
                });
              }
            });
          }

          final slot = u["working_hours_slot"] as String? ?? "";
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.blueGrey[200],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shield, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Force Controls",
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900])),
                        Text(u["username"] ?? "",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey[600])),
                      ]),
                ),
              ]),

              if (slot.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(children: [
                    Icon(Icons.schedule,
                        color: Colors.orange[700], size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          "Only works during: ${_slot(slot)}",
                          style: TextStyle(
                              color: Colors.orange[800], fontSize: 11)),
                    ),
                  ]),
                ),

              const SizedBox(height: 14),

              // Loading or controls
              loadingInit
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator())
                  : Column(children: [
                      _forceRow(
                        Icons.location_on,
                        Colors.blue[700]!,
                        "GPS Tracking",
                        trackOn,
                        () async {
                          final ok = await c.forceTracking(
                              userId: u["id"], enabled: true);
                          if (ok) ss(() => trackOn = true);
                        },
                        () async {
                          final ok = await c.forceTracking(
                              userId: u["id"], enabled: false);
                          if (ok) ss(() => trackOn = false);
                        },
                      ),
                      const SizedBox(height: 10),
                      _forceRow(
                        Icons.mic,
                        Colors.purple,
                        "Voice Recording",
                        recOn,
                        () async {
                          final ok = await c.forceRecording(
                              userId: u["id"], enabled: true);
                          if (ok) ss(() => recOn = true);
                        },
                        () async {
                          final ok = await c.forceRecording(
                              userId: u["id"], enabled: false);
                          if (ok) ss(() => recOn = false);
                        },
                      ),
                    ]),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  // ✅ FIXED
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey[700],
                      side: BorderSide(color: Colors.blueGrey[300]!),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text("Close"),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _forceRow(
    IconData icon,
    Color color,
    String title,
    bool isOn,
    Future<void> Function() onOn,
    Future<void> Function() onOff,
  ) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey[200]!)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.blueGrey[900],
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(
                      isOn ? "Currently FORCED ON" : "Currently OFF",
                      style: TextStyle(
                          color: isOn
                              ? Colors.red[700]
                              : Colors.blueGrey[500],
                          fontSize: 11)),
                ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: ElevatedButton(
              onPressed: isOn ? onOff : onOn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOn
                    ? Colors.red.withOpacity(0.12)
                    : color.withOpacity(0.12),
                foregroundColor:
                    isOn ? Colors.red[700] : color,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: isOn
                            ? Colors.red.withOpacity(0.4)
                            : color.withOpacity(0.4))),
              ),
              child: Text(
                  isOn ? "OFF" : "Force ON",
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  // ================================================================
  // RECORDINGS SHEET  — FIXED: () => Get.back()
  // ================================================================
  void _showRecordingsSheet(BuildContext ctx, Map u) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (sheetCtx, sc) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color:
                          Colors.orange[700]!.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.mic,
                      color: Colors.orange[700], size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      "Recordings — ${u['username']}",
                      style: TextStyle(
                          color: Colors.blueGrey[900],
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ),
                // ✅ FIXED
                IconButton(
                  icon: Icon(Icons.close,
                      color: Colors.blueGrey[500]),
                  onPressed: () => Get.back(),
                ),
              ]),
            ),
            Divider(color: Colors.blueGrey[100], height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: c.loadRecordings(u["id"] as int),
                builder: (_, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: Colors.blueGrey[700]));
                  }
                  final recs = snap.data ?? [];
                  if (recs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_off,
                              size: 64,
                              color: Colors.blueGrey[300]),
                          const SizedBox(height: 12),
                          Text("No recordings yet",
                              style: TextStyle(
                                  color: Colors.blueGrey[500])),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: recs.length,
                    itemBuilder: (_, i) => _recCard(recs[i]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _recCard(Map<String, dynamic> r) {
    final dur    = r["duration_seconds"] as int? ?? 0;
    final mins   = dur ~/ 60;
    final secs   = dur % 60;
    final durStr = "$mins:${secs.toString().padLeft(2, '0')}";
    final started = r["started_at"] as String? ?? "";
    final fname   = r["filename"] as String? ?? "Recording ${r['id']}";
    final base    = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api$'), '');
    final url     = "$base${r['download_url']}";
    final token   = GetStorage().read("token") ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey[200]!),
        boxShadow: [BoxShadow(
            color: Colors.blueGrey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: Colors.orange[700]!.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.audio_file,
              color: Colors.orange[700], size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fname,
                    style: TextStyle(
                        color: Colors.blueGrey[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_fmt(started),
                    style: TextStyle(
                        color: Colors.blueGrey[600], fontSize: 11)),
                if (dur > 0)
                  Text("Duration: $durStr",
                      style: TextStyle(
                          color: Colors.blue[700], fontSize: 11)),
              ]),
        ),
        IconButton(
          icon: Icon(Icons.play_circle,
              color: Colors.orange[700], size: 30),
          onPressed: () async {
            final uri =
                Uri.parse("$url?token=$token");
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        ),
      ]),
    );
  }
}

// ================================================================
// RECORDINGS PREVIEW WIDGET
// ================================================================
class _RecPreview extends StatefulWidget {
  final int userId;
  final MasterAdminController controller;
  final String baseUrl;

  const _RecPreview({
    required this.userId,
    required this.controller,
    required this.baseUrl,
  });

  @override
  State<_RecPreview> createState() => _RecPreviewState();
}

class _RecPreviewState extends State<_RecPreview> {
  List<Map<String, dynamic>> _recs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.loadRecordings(widget.userId).then((r) {
      if (mounted) {
        setState(() {
          _recs    = r.take(3).toList();
          _loading = false;
        });
      }
    });
  }

  String _fmt(String? ts) {
    if (ts == null || ts.isEmpty) return "—";
    try {
      final dt = DateTime.parse(ts).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(14),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_recs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text("No recordings yet",
            style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
      );
    }

    return Column(
      children: _recs.map((r) {
        final dur   = r["duration_seconds"] as int? ?? 0;
        final mins  = dur ~/ 60;
        final secs  = dur % 60;
        final base  = widget.baseUrl.replaceAll(RegExp(r'/api$'), '');
        final url   = "$base${r['download_url']}";
        final token = GetStorage().read("token") ?? "";

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey[200]!)),
          child: Row(children: [
            Icon(Icons.audio_file,
                color: Colors.orange[700], size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmt(r["started_at"]),
                        style: TextStyle(
                            color: Colors.blueGrey[600], fontSize: 11)),
                    if (dur > 0)
                      Text(
                          "$mins:${secs.toString().padLeft(2, '0')}",
                          style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                  ]),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.play_circle,
                  color: Colors.orange[700], size: 26),
              onPressed: () async {
                final uri = Uri.parse("$url?token=$token");
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ]),
        );
      }).toList(),
    );
  }
}