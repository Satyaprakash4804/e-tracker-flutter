import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../../controllers/master_admin_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/geofence_controller.dart';
import '../../routes/app_routes.dart';
import '../../constants/api_endpoints.dart';

// ─── Design tokens ───────────────────────────────────────────────
const _kPrimary   = Color(0xFF1E3A5F);   // deep navy
const _kAccent    = Color(0xFF2DD4BF);   // teal
const _kSurface   = Color(0xFFF8FAFC);
const _kCard      = Colors.white;
const _kTextPri   = Color(0xFF0F172A);
const _kTextSec   = Color(0xFF64748B);
const _kBorder    = Color(0xFFE2E8F0);
const _kOnline    = Color(0xFF22C55E);
const _kOffline   = Color(0xFFEF4444);
const _kWarning   = Color(0xFFF59E0B);

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
    if (!Get.isRegistered<AdminController>())    Get.put(AdminController());
    if (!Get.isRegistered<GeofenceController>()) Get.put(GeofenceController());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  bool _isOnline(Map u) {
    final last = u["last_update"];
    if (last == null || last.toString().isEmpty) return false;
    try {
      return DateTime.now().toUtc()
          .difference(_parseTs(last.toString())!.toUtc()).inSeconds <= 30;
    } catch (_) { return false; }
  }

  /// Robustly parses MySQL timestamps (both "2026-05-20 12:34:56" and ISO)
  DateTime? _parseTs(String? ts) {
    if (ts == null || ts.trim().isEmpty) return null;
    try {
      // Replace space separator with T for ISO compliance
      final normalised = ts.trim().replaceFirst(RegExp(r' (?=\d{2}:\d{2})'), 'T');
      return DateTime.parse(normalised);
    } catch (_) { return null; }
  }

  String _fmt(String? ts) {
    if (ts == null || ts.trim().isEmpty) return "Never";
    final dt = _parseTs(ts);
    if (dt == null) return "—";
    final local = dt.toLocal();
    final now   = DateTime.now();
    final diff  = now.difference(local);
    if (diff.inSeconds < 60)  return "Just now";
    if (diff.inMinutes < 60)  return "${diff.inMinutes}m ago";
    if (diff.inHours   < 24)  return "${diff.inHours}h ago";
    if (diff.inDays    < 7)   return "${diff.inDays}d ago";
    return "${local.day.toString().padLeft(2,'0')}-"
           "${local.month.toString().padLeft(2,'0')}-"
           "${local.year} "
           "${local.hour.toString().padLeft(2,'0')}:"
           "${local.minute.toString().padLeft(2,'0')}";
  }

  String _slot(String? s) => const {
    '9-5':  '09:00–17:00  Day',
    '5-1':  '17:00–01:00  Eve',
    '1-9':  '01:00–09:00  Night',
    '24-7': '24 / 7  Always Active',
  }[s] ?? 'Not Set';

  String? _imgUrl(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return "${ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api$'), '')}$p";
  }

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int)  return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  List<Map<String, dynamic>> get _filtered {
    final role = _roleFilter.value;
    final q    = _searchQ.value.toLowerCase();
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

  bool _isWide(BuildContext ctx)  => MediaQuery.of(ctx).size.width >= 700;
  bool _isSmall(BuildContext ctx) => MediaQuery.of(ctx).size.width < 420;

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final wide   = _isWide(context);
      final small  = _isSmall(context);

      Widget page;
      bool showFab = false;
      switch (_navIdx.value) {
        case 0: page = _dashboardPage(wide, small); showFab = true; break;
        case 1: page = _specialPage(small);         break;
        case 2: page = _recordingsPage(small);      break;
        case 3: page = _settingsPage(small);        break;
        default: page = _dashboardPage(wide, small); showFab = true;
      }

      return Scaffold(
        backgroundColor: _kSurface,
        drawer: _navIdx.value == 0 ? _drawer() : null,
        body: SafeArea(child: page),
        floatingActionButton: showFab ? _fab(small) : null,
        bottomNavigationBar: _bottomNav(),
      );
    });
  }

  // ── FAB ─────────────────────────────────────────────────────────
  Widget _fab(bool small) => FloatingActionButton.extended(
    onPressed: () => _showCreateSheet(context),
    backgroundColor: _kPrimary,
    elevation: 4,
    icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
    label: Text(
      small ? "Add" : "Add User",
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
          fontSize: 13),
    ),
  );

  // ── Bottom Nav ───────────────────────────────────────────────────
  Widget _bottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded,   'label': 'Dashboard'},
      {'icon': Icons.shield_rounded,      'label': 'Special'},
      {'icon': Icons.mic_rounded,         'label': 'Recordings'},
      {'icon': Icons.public_rounded,      'label': 'Geofence'},
      {'icon': Icons.settings_rounded,    'label': 'Settings'},
    ];
    return Obx(() => Container(
      decoration: BoxDecoration(
        color: _kCard,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, -3))],
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
                  width: 56,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44, height: 30,
                      decoration: BoxDecoration(
                        color: active ? _kPrimary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        items[i]['icon'] as IconData,
                        size: 19,
                        color: active ? _kPrimary : _kTextSec,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? _kPrimary : _kTextSec,
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    ));
  }

  // ── Drawer ───────────────────────────────────────────────────────
  Widget _drawer() => Drawer(
    child: Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          bottom: 24, left: 20, right: 20,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kPrimary, Color(0xFF2D5986)],
          ),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings_rounded,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text("Master Admin",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kAccent.withOpacity(0.5)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_rounded, color: _kAccent, size: 12),
              SizedBox(width: 4),
              Text("MASTER ADMIN",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: _kAccent, letterSpacing: 0.8)),
            ]),
          ),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _dItem(Icons.dashboard_rounded, "Dashboard", () => Get.back()),
        _dItem(Icons.person_add_rounded, "Create User", () {
          Get.back();
          _showCreateSheet(context);
        }),
        _dItem(Icons.shield_rounded, "Special Employees", () {
          Get.back(); _navIdx.value = 1;
        }),
        _dItem(Icons.mic_rounded, "Recordings", () {
          Get.back(); _navIdx.value = 2;
        }),
        _dItem(Icons.public_rounded, "Global Geofence", () {
          Get.back();
          Get.toNamed(Routes.ADMIN_GLOBAL_GEOFENCE);
        }),
        const Divider(height: 24, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text("ALERT SETTINGS",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kTextSec, letterSpacing: 1)),
        ),
        Obx(() => _dSwitch(Icons.notifications_active_rounded,
            "Geofence Alerts", c.geofenceAlertOn.value, c.toggleGeofenceAlert)),
        Obx(() => _dSwitch(Icons.battery_alert_rounded,
            "Battery Alerts", c.batteryAlertOn.value, c.toggleBatteryAlert)),
      ])),
      const Divider(height: 1),
      _dItem(Icons.logout_rounded, "Sign Out", () {
        GetStorage().erase();
        Get.offAllNamed(Routes.LOGIN);
      }, color: _kOffline),
      const SizedBox(height: 8),
    ]),
  );

  Widget _dItem(IconData icon, String title, VoidCallback onTap, {Color? color}) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: (color ?? _kPrimary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color ?? _kPrimary, size: 20),
        ),
        title: Text(title, style: TextStyle(
            color: color ?? _kTextPri, fontWeight: FontWeight.w600,
            fontSize: 14)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      );

  Widget _dSwitch(IconData icon, String title, bool value, Function(bool) cb) =>
      SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _kPrimary, size: 20),
        ),
        title: Text(title, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14, color: _kTextPri)),
        value: value, onChanged: cb, activeColor: _kAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      );

  // ================================================================
  // PAGE 0 — DASHBOARD
  // ================================================================
  Widget _dashboardPage(bool wide, bool small) {
    return Column(children: [
      _appBar(small),
      _roleTabs(small),
      _searchBar(small),
      Expanded(child: Obx(() {
        if (c.loading.value) {
          return Center(child: CircularProgressIndicator(color: _kPrimary));
        }
        final list = _filtered;
        if (list.isEmpty) {
          return _emptyState("No users found", Icons.people_outline_rounded);
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              small ? 12 : 16, 8, small ? 12 : 16, 100),
          itemCount: list.length,
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 860 : double.infinity),
              child: _userCard(list[i], small, wide),
            ),
          ),
        );
      })),
    ]);
  }

  // ── App Bar ──────────────────────────────────────────────────────
  Widget _appBar(bool small) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          small ? 12 : 20, small ? 14 : 18, small ? 12 : 20, small ? 14 : 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kPrimary, Color(0xFF2D5986)],
        ),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        boxShadow: [BoxShadow(
            color: Color(0x331E3A5F), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          Builder(builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Master Admin",
                style: TextStyle(
                    fontSize: small ? 17 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text("Control Panel",
                style: TextStyle(
                    fontSize: small ? 10 : 12,
                    color: Colors.white.withOpacity(0.75))),
          ])),
          GestureDetector(
            onTap: c.loadUsers,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _statsRow(small),
      ]),
    );
  }

  Widget _statsRow(bool small) {
    return Obx(() {
      final total  = c.allUsers.where((u) => u["role"] != "master_admin").length;
      final online = c.allUsers.where(_isOnline).length;
      final sp     = c.specialEmployees.length;
      final lowBat = c.allUsers.where((u) {
        final b = u["battery"] as int? ?? -1;
        return b != -1 && b < 25;
      }).length;

      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 16, vertical: small ? 10 : 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem("Total",   total.toString(),  Icons.people_rounded,         Colors.white, small),
            _statDivider(),
            _statItem("Online",  online.toString(), Icons.wifi_rounded,           _kAccent,     small),
            _statDivider(),
            _statItem("Special", sp.toString(),     Icons.shield_rounded,         Colors.white, small),
            _statDivider(),
            _statItem("Low Bat", lowBat.toString(), Icons.battery_alert_rounded,
                lowBat > 0 ? const Color(0xFFFF8A80) : Colors.white, small),
          ],
        ),
      );
    });
  }

  Widget _statItem(String label, String val, IconData icon, Color color, bool small) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: small ? 15 : 18),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(
            color: color, fontSize: small ? 14 : 17, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: small ? 8 : 9, fontWeight: FontWeight.w500)),
      ]);

  Widget _statDivider() => Container(
      width: 1, height: 28, color: Colors.white.withOpacity(0.25));

  // ── Role Tabs ────────────────────────────────────────────────────
  Widget _roleTabs(bool small) => Obx(() {
    final all = c.allUsers.where((u) => u["role"] != "master_admin").length;
    return Container(
      margin: EdgeInsets.fromLTRB(small ? 12 : 16, 14, small ? 12 : 16, 0),
      height: 44,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
            color: _kPrimary, borderRadius: BorderRadius.circular(10)),
        labelColor: Colors.white,
        unselectedLabelColor: _kTextSec,
        labelStyle: TextStyle(
            fontSize: small ? 10 : 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: small ? 9 : 11),
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: small ? "All\n$all" : "All ($all)"),
          Tab(text: small ? "Adm\n${c.admins.length}" : "Admin (${c.admins.length})"),
          Tab(text: small ? "Emp\n${c.employees.length}" : "Emp (${c.employees.length})"),
          Tab(text: small ? "Sp\n${c.specialEmployees.length}" : "Special (${c.specialEmployees.length})"),
        ],
      ),
    );
  });

  // ── Search ───────────────────────────────────────────────────────
  Widget _searchBar(bool small) => Padding(
    padding: EdgeInsets.fromLTRB(
        small ? 12 : 16, 10, small ? 12 : 16, 4),
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => _searchQ.value = v,
        style: TextStyle(fontSize: small ? 13 : 14, color: _kTextPri),
        decoration: InputDecoration(
          hintText: "Search users…",
          hintStyle: TextStyle(color: _kTextSec, fontSize: small ? 13 : 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _kTextSec, size: 20),
          suffixIcon: Obx(() => _searchQ.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kTextSec, size: 18),
                  onPressed: () { _searchCtrl.clear(); _searchQ.value = ''; })
              : const SizedBox.shrink()),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  );

  // ================================================================
  // USER CARD
  // ================================================================
  Widget _userCard(Map<String, dynamic> u, bool small, bool wide) {
    final online   = _isOnline(u);
    final role     = u["role"] as String? ?? "employee";
    final isSP     = role == "special_employee";
    final isEmp    = role == "employee" || isSP;
    final bat      = u["battery"] as int? ?? -1;
    final lowBat   = bat != -1 && bat < 25;
    final reg      = _toBool(u["registration_completed"]);
    final img      = _imgUrl(u["selfie_path"]);
    final hasShift = (u["working_hours_slot"] as String? ?? "").isNotEmpty;
    final createdBy = u["created_by_username"] as String?;

    return Container(
      margin: EdgeInsets.only(bottom: small ? 10 : 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: online ? _kOnline.withOpacity(0.35) : _kBorder,
            width: online ? 1.5 : 1),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(small ? 12 : 14),
          decoration: BoxDecoration(
            color: online
                ? _kOnline.withOpacity(0.05)
                : _kPrimary.withOpacity(0.03),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17), topRight: Radius.circular(17)),
          ),
          child: Row(children: [
            // Avatar
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
                        color: online ? _kOnline : _kBorder, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: small ? 24 : 28,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: img != null ? NetworkImage(img) : null,
                    child: img == null
                        ? Icon(Icons.person_rounded,
                            color: _kTextSec, size: small ? 22 : 26)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 1, right: 1,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: online ? _kOnline : _kOffline,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username + role badge in one row
                  Row(children: [
                    Expanded(
                      child: Text(
                        u["username"] ?? "Unknown",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: small ? 14 : 15,
                            color: _kTextPri),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _rolePill(role, small),
                  ]),
                  const SizedBox(height: 4),
                  // Created by + registration status row
                  Wrap(spacing: 6, runSpacing: 3, children: [
                    _statusPill(
                        online ? "Online" : "Offline",
                        online ? _kOnline : _kOffline, small),
                    _statusPill(
                        reg ? "Registered" : "Pending",
                        reg ? const Color(0xFF3B82F6) : _kWarning, small),
                    if (createdBy != null && createdBy.isNotEmpty)
                      _createdByPill(createdBy, small),
                  ]),
                ])),
          ]),
        ),

        // ── Body (employees) ────────────────────────────────────
        if (isEmp) _empBody(u, small, wide, bat, lowBat),

        // ── Actions ─────────────────────────────────────────────
        _actionBar(u, small, isEmp, isSP, hasShift),
      ]),
    );
  }

  Widget _empBody(Map u, bool small, bool wide, int bat, bool lowBat) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          small ? 12 : 14, 10, small ? 12 : 14, 4),
      child: wide
          ? Row(children: [
              Expanded(child: Column(children: [
                _infoTile(Icons.location_on_rounded, "Location",
                    u["lat"] != null ? "${u['lat']}, ${u['lng']}" : "Not available",
                    small),
                const SizedBox(height: 8),
                _infoTile(Icons.battery_charging_full_rounded, "Battery",
                    bat == -1 ? "N/A" : "$bat%", small,
                    valueColor: lowBat ? _kOffline : _kOnline),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(children: [
                _infoTile(Icons.access_time_rounded, "Last Update",
                    _fmt(u["last_update"]), small),
                const SizedBox(height: 8),
                _infoTile(Icons.schedule_rounded, "Shift",
                    _slot(u["working_hours_slot"]), small),
              ])),
            ])
          : Column(children: [
              _infoTile(Icons.access_time_rounded, "Last Update",
                  _fmt(u["last_update"]), small),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(child: _infoTile(
                    Icons.battery_charging_full_rounded, "Battery",
                    bat == -1 ? "N/A" : "$bat%", small,
                    valueColor: lowBat ? _kOffline : _kOnline)),
                const SizedBox(width: 8),
                Expanded(child: _infoTile(
                    Icons.schedule_rounded, "Shift",
                    _slot(u["working_hours_slot"]), small)),
              ]),
            ]),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool small,
      {Color? valueColor}) =>
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12, vertical: small ? 7 : 9),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: small ? 14 : 16, color: _kPrimary.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: small ? 9 : 10,
                    color: _kTextSec,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: small ? 11 : 12,
                    color: valueColor ?? _kTextPri,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  Widget _actionBar(Map u, bool small, bool isEmp, bool isSP, bool hasShift) =>
      Container(
        padding: EdgeInsets.all(small ? 10 : 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(17),
              bottomRight: Radius.circular(17)),
          border: const Border(top: BorderSide(color: _kBorder)),
        ),
        child: Wrap(
          spacing: 6, runSpacing: 6,
          alignment: WrapAlignment.start,
          children: [
            if (isEmp) ...[
              _actBtn("Profile", Icons.person_rounded,
                  const Color(0xFF475569), small,
                  () => Get.toNamed(Routes.ADMIN_EMPLOYEE_PROFILE,
                      arguments: u["id"])),
              _actBtn("Track", Icons.timeline_rounded,
                  const Color(0xFF2563EB), small,
                  () => Get.toNamed(Routes.TRACK_RECORD,
                      arguments: {"user_id": u["id"], "name": u["username"]})),
              _actBtn("Geo", Icons.map_rounded,
                  const Color(0xFF059669), small, () => _openGeofence(u)),
              if (!hasShift)
                _actBtn("Set Shift", Icons.schedule_rounded,
                    const Color(0xFF0D9488), small,
                    () => _showHoursSheet(context, u)),
            ],
            if (isSP) ...[
              _actBtn("Force", Icons.shield_rounded,
                  const Color(0xFF7C3AED), small,
                  () => _showForceSheet(context, u)),
              _actBtn("Recs", Icons.mic_rounded,
                  const Color(0xFFEA580C), small,
                  () => _showRecordingsSheet(context, u)),
            ],
            _actBtn("Delete", Icons.delete_rounded,
                _kOffline, small, () => _confirmDelete(u)),
          ],
        ),
      );

  // ── Pills & badges ───────────────────────────────────────────────
  Widget _rolePill(String role, bool small) {
    final label = role == 'admin' ? 'Admin'
        : role == 'special_employee' ? 'Special' : 'Employee';
    final color = role == 'admin' ? const Color(0xFF2563EB)
        : role == 'special_employee' ? const Color(0xFF7C3AED)
        : const Color(0xFF059669);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label,
          style: TextStyle(fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _statusPill(String label, Color color, bool small) =>
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(fontSize: small ? 8 : 9,
                fontWeight: FontWeight.w600, color: color)),
      );

  Widget _createdByPill(String adminName, bool small) =>
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kPrimary.withOpacity(0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_accounts_rounded,
              size: small ? 9 : 10, color: _kPrimary.withOpacity(0.7)),
          const SizedBox(width: 3),
          Text("by $adminName",
              style: TextStyle(
                  fontSize: small ? 8 : 9,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary.withOpacity(0.8))),
        ]),
      );

  Widget _actBtn(String label, IconData icon, Color color,
      bool small, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 10 : 12, vertical: small ? 7 : 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: small ? 14 : 16, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(fontSize: small ? 10 : 11,
                    fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: _kTextSec.withOpacity(0.35)),
      const SizedBox(height: 14),
      Text(msg, style: const TextStyle(
          fontSize: 15, color: _kTextSec, fontWeight: FontWeight.w500)),
    ]),
  );

  // ================================================================
  // PAGE 1 — SPECIAL EMPLOYEES
  // ================================================================
  Widget _specialPage(bool small) => Column(children: [
    _subHeader("Special Employees", "Force controls & recordings", small),
    Expanded(child: Obx(() {
      final list = c.specialEmployees;
      if (list.isEmpty) return _emptyState("No special employees", Icons.shield_outlined);
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(small ? 12 : 16, 14, small ? 12 : 16, 100),
        itemCount: list.length,
        itemBuilder: (_, i) => _userCard(list[i], small, true),
      );
    })),
  ]);

  // ================================================================
  // PAGE 2 — RECORDINGS
  // ================================================================
  Widget _recordingsPage(bool small) => Column(children: [
    _subHeader("Voice Recordings", "All special employee recordings", small),
    Expanded(child: Obx(() {
      final sps = c.specialEmployees;
      if (sps.isEmpty) return _emptyState("No special employees", Icons.mic_off_rounded);
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(small ? 12 : 16, 14, small ? 12 : 16, 100),
        itemCount: sps.length,
        itemBuilder: (_, i) => _empRecSection(sps[i], small),
      );
    })),
  ]);

  Widget _empRecSection(Map<String, dynamic> u, bool small) {
    final img = _imgUrl(u["selfie_path"]);
    return Container(
      margin: EdgeInsets.only(bottom: small ? 10 : 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: EdgeInsets.all(small ? 12 : 14),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7ED),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: small ? 18 : 22,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: img != null ? NetworkImage(img) : null,
              child: img == null
                  ? Icon(Icons.person_rounded, color: _kTextSec,
                      size: small ? 16 : 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u["username"] ?? "?",
                  style: TextStyle(
                      color: _kTextPri, fontSize: small ? 13 : 14,
                      fontWeight: FontWeight.w700)),
              Text(_slot(u["working_hours_slot"]),
                  style: TextStyle(color: _kTextSec,
                      fontSize: small ? 10 : 11)),
            ])),
            _actBtn("View All", Icons.mic_rounded,
                const Color(0xFFEA580C), small,
                () => _showRecordingsSheet(context, u)),
          ]),
        ),
        _RecPreview(userId: u["id"] as int, controller: c,
            baseUrl: ApiEndpoints.baseUrl),
      ]),
    );
  }

  // ================================================================
  // PAGE 3 — SETTINGS
  // ================================================================
  Widget _settingsPage(bool small) => Column(children: [
    _subHeader("Settings", "Alerts & preferences", small),
    Expanded(child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          small ? 12 : 16, 20, small ? 12 : 16, 100),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel("Alert Settings"),
          const SizedBox(height: 10),
          Obx(() => _toggleCard(Icons.notifications_active_rounded,
              "Geofence Alerts", "Notify on geofence enter/exit",
              c.geofenceAlertOn.value, c.toggleGeofenceAlert)),
          const SizedBox(height: 10),
          Obx(() => _toggleCard(Icons.battery_alert_rounded,
              "Battery Alerts", "Notify when battery < 25%",
              c.batteryAlertOn.value, c.toggleBatteryAlert)),
          const SizedBox(height: 24),
          _sectionLabel("Quick Actions"),
          const SizedBox(height: 10),
          _settingTile("Create New User", Icons.person_add_rounded,
              _kPrimary, () => _showCreateSheet(context)),
          const SizedBox(height: 10),
          _settingTile("Refresh All Data", Icons.refresh_rounded,
              const Color(0xFF2563EB), c.loadUsers),
          const SizedBox(height: 24),
          _sectionLabel("Account"),
          const SizedBox(height: 10),
          _settingTile("Sign Out", Icons.logout_rounded, _kOffline, () {
            GetStorage().erase();
            Get.offAllNamed(Routes.LOGIN);
          }),
        ]),
      )),
    )),
  ]);

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Text(t.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: _kTextSec, letterSpacing: 1)),
  );

  Widget _toggleCard(IconData icon, String title, String sub,
      bool value, Function(bool) cb) =>
      Container(
        decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _kPrimary, size: 20),
          ),
          title: Text(title, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: _kTextPri)),
          subtitle: Text(sub, style: const TextStyle(
              color: _kTextSec, fontSize: 11)),
          value: value, onChanged: cb, activeColor: _kAccent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      );

  Widget _settingTile(String label, IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              color: _kCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w600,
                    color: _kTextPri, fontSize: 14))),
            Icon(Icons.chevron_right_rounded, color: _kTextSec.withOpacity(0.5)),
          ]),
        ),
      );

  // ── Sub-page header ──────────────────────────────────────────────
  Widget _subHeader(String title, String sub, bool small) => Container(
    padding: EdgeInsets.fromLTRB(
        small ? 12 : 20, small ? 14 : 18, small ? 12 : 20, small ? 14 : 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kPrimary, Color(0xFF2D5986)]),
      borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      boxShadow: [BoxShadow(
          color: Color(0x331E3A5F), blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => _navIdx.value = 0,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            fontSize: small ? 15 : 18, fontWeight: FontWeight.bold,
            color: Colors.white)),
        Text(sub, style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.75))),
      ])),
    ]),
  );

  // ================================================================
  // DIALOGS & SHEETS
  // ================================================================
  void _confirmDelete(Map u) => Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Delete User",
          style: TextStyle(fontWeight: FontWeight.bold, color: _kTextPri)),
      content: Text("Delete \"${u['username']}\"? Cannot be undone.",
          style: const TextStyle(color: _kTextSec)),
      actions: [
        TextButton(onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: _kTextSec))),
        ElevatedButton(
          onPressed: () { Get.back(); c.deleteUser(u["id"]); },
          style: ElevatedButton.styleFrom(
              backgroundColor: _kOffline,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: const Text("Delete",
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  InputDecoration _iDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _kTextSec),
    prefixIcon: Icon(icon, color: _kTextSec, size: 20),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 2)),
    filled: true,
    fillColor: _kSurface,
  );

  void _showCreateSheet(BuildContext ctx) {
    final unCtrl = TextEditingController();
    final pwCtrl = TextEditingController();
    String role = 'employee', slot = '';
    bool showPw = false;
    final fk = GlobalKey<FormState>();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Form(
                key: fk,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _kBorder,
                          borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_add_rounded,
                          color: _kPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text("Create New User",
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.bold, color: _kTextPri)),
                  ]),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: unCtrl,
                    decoration: _iDeco("Username", Icons.person_outline_rounded),
                    validator: (v) => (v?.length ?? 0) < 3 ? "Min 3 chars" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pwCtrl,
                    obscureText: !showPw,
                    decoration: _iDeco("Password", Icons.lock_outline_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            showPw ? Icons.visibility_off_rounded
                                   : Icons.visibility_rounded,
                            color: _kTextSec, size: 20),
                        onPressed: () => ss(() => showPw = !showPw),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) < 6 ? "Min 6 chars" : null,
                  ),
                  const SizedBox(height: 16),
                  const Text("Role",
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: _kTextPri, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _roleChip("admin", "Admin",
                        Icons.admin_panel_settings_rounded, role,
                        (v) => ss(() { role = v; slot = ''; })),
                    const SizedBox(width: 8),
                    _roleChip("employee", "Employee",
                        Icons.badge_rounded, role,
                        (v) => ss(() { role = v; slot = ''; })),
                    const SizedBox(width: 8),
                    _roleChip("special_employee", "Special",
                        Icons.shield_rounded, role,
                        (v) => ss(() { role = v; slot = ''; })),
                  ]),
                  if (role == 'employee' || role == 'special_employee') ...[
                    const SizedBox(height: 16),
                    const Text("Working Hours Slot",
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: _kTextPri, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _slotChip('9-5', '09–17', 'Day',   slot, (v) => ss(() => slot = v)),
                      const SizedBox(width: 8),
                      _slotChip('5-1', '17–01', 'Eve',   slot, (v) => ss(() => slot = v)),
                      const SizedBox(width: 8),
                      _slotChip('1-9', '01–09', 'Night', slot, (v) => ss(() => slot = v)),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextSec,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text("Cancel"),
                    )),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: Obx(() => ElevatedButton(
                      onPressed: c.loadingCreate.value ? null : () {
                        if (!fk.currentState!.validate()) return;
                        c.createUser(
                            username: unCtrl.text.trim(),
                            password: pwCtrl.text.trim(),
                            role: role,
                            workingHoursSlot: slot.isEmpty ? null : slot);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: c.loadingCreate.value
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("Create User",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String val, String label, IconData icon,
      String cur, Function(String) onTap) {
    final active = cur == val;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kPrimary.withOpacity(0.1) : _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? _kPrimary : _kBorder, width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, size: 18,
              color: active ? _kPrimary : _kTextSec),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: active ? _kPrimary : _kTextSec)),
        ]),
      ),
    ));
  }

  Widget _slotChip(String val, String time, String label,
      String cur, Function(String) onTap) {
    final active = cur == val;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kAccent.withOpacity(0.1) : _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? _kAccent : _kBorder,
              width: active ? 2 : 1.5),
        ),
        child: Column(children: [
          Text(time, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: active ? _kPrimary : _kTextPri)),
          Text(label, style: TextStyle(fontSize: 9,
              color: active ? _kTextSec : _kTextSec)),
        ]),
      ),
    ));
  }

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text("Set Working Hours",
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.bold, color: _kTextPri)),
            Text("For: ${u['username']}",
                style: const TextStyle(fontSize: 13, color: _kTextSec)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kWarning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kWarning.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.lock_rounded, color: _kWarning, size: 14),
                const SizedBox(width: 6),
                const Expanded(child: Text(
                    "Once set, working hours CANNOT be changed.",
                    style: TextStyle(color: _kWarning, fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _slotChip('9-5', '09–17', 'Day',   sel, (v) => ss(() => sel = v)),
              const SizedBox(width: 8),
              _slotChip('5-1', '17–01', 'Eve',   sel, (v) => ss(() => sel = v)),
              const SizedBox(width: 8),
              _slotChip('1-9', '01–09', 'Night', sel, (v) => ss(() => sel = v)),
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
                  Navigator.of(sheetCtx2).pop();
                  c.setWorkingHours(userId: u["id"], slot: sel);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
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

  void _showForceSheet(BuildContext ctx, Map u) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ForceControlSheet(user: u, controller: c),
  );

  void _showRecordingsSheet(BuildContext ctx, Map u) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (sheetCtx, sc) => Container(
        decoration: const BoxDecoration(
            color: _kCard,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.mic_rounded,
                    color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  "Recordings — ${u['username']}",
                  style: const TextStyle(
                      color: _kTextPri, fontSize: 15,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: Icon(Icons.close_rounded, color: _kTextSec),
                onPressed: () => Get.back(),
              ),
            ]),
          ),
          const Divider(color: _kBorder, height: 1),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: c.loadRecordings(u["id"] as int),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _kPrimary));
              }
              final recs = snap.data ?? [];
              if (recs.isEmpty) {
                return _emptyState("No recordings yet", Icons.mic_off_rounded);
              }
              return ListView.builder(
                controller: sc,
                padding: const EdgeInsets.all(16),
                itemCount: recs.length,
                itemBuilder: (_, i) => _recCard(recs[i]),
              );
            },
          )),
        ]),
      ),
    ),
  );

  Widget _recCard(Map<String, dynamic> r) {
    final dur     = r["duration_seconds"] as int? ?? 0;
    final mins    = dur ~/ 60;
    final secs    = dur % 60;
    final started = r["started_at"] as String? ?? "";
    final fname   = r["filename"] as String? ?? "Recording ${r['id']}";

    final base         = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final downloadPath = r['download_url'] as String? ?? '';
    final url          = downloadPath.startsWith('http')
        ? downloadPath : '$base$downloadPath';
    final token = GetStorage().read("token") ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.audio_file_rounded,
              color: Color(0xFFEA580C), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fname,
              style: const TextStyle(
                  color: _kTextPri, fontSize: 12,
                  fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(_fmt(started),
              style: const TextStyle(color: _kTextSec, fontSize: 11)),
          if (dur > 0)
            Text("$mins:${secs.toString().padLeft(2, '0')}",
                style: const TextStyle(
                    color: Color(0xFF2563EB), fontSize: 11,
                    fontWeight: FontWeight.w600)),
        ])),
        IconButton(
          icon: const Icon(Icons.play_circle_rounded,
              color: Color(0xFFEA580C), size: 32),
          onPressed: () async {
            final player = AudioPlayer();
            final uri = Uri.parse(url).replace(
                queryParameters: {'token': token});
            try {
              await player.setUrl(uri.toString());
              await player.play();
            } catch (e) {
              Get.snackbar("Playback Error", "Could not play: $e",
                  snackPosition: SnackPosition.BOTTOM);
            }
          },
        ),
      ]),
    );
  }
}

// ================================================================
// FORCE CONTROL SHEET
// ================================================================
class _ForceControlSheet extends StatefulWidget {
  final Map user;
  final MasterAdminController controller;
  const _ForceControlSheet({required this.user, required this.controller});
  @override
  State<_ForceControlSheet> createState() => _ForceControlSheetState();
}

class _ForceControlSheetState extends State<_ForceControlSheet> {
  bool _loading = true;
  bool _trackOn = false;
  bool _recOn   = false;
  String? _errorMsg;

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  String _slot(String? s) => const {
    '9-5': '09:00–17:00  Day',
    '5-1': '17:00–01:00  Eve',
    '1-9': '01:00–09:00  Night',
  }[s] ?? 'Not Set';

  @override
  void initState() { super.initState(); _fetchStatus(); }

  Future<void> _fetchStatus() async {
    if (!mounted) return;
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final data = await widget.controller
          .getControlStatus(widget.user["id"]);
      if (!mounted) return;
      if (data != null && _toBool(data["success"])) {
        setState(() {
          _trackOn = _toBool(data["tracking"]?["effective"]);
          _recOn   = _toBool(data["recording"]?["effective"]);
          _loading = false;
        });
      } else {
        setState(() {
          _errorMsg = data?["message"] ?? "Failed to load status";
          _loading  = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMsg = "Network error: $e"; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u    = widget.user;
    final slot = u["working_hours_slot"] as String? ?? "";

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield_rounded,
                color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Force Controls",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.bold, color: _kTextPri)),
            Text(u["username"] ?? "",
                style: const TextStyle(fontSize: 13, color: _kTextSec)),
          ])),
        ]),
        if (slot.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _kWarning.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kWarning.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.schedule_rounded, color: _kWarning, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text("Only works during: ${_slot(slot)}",
                  style: TextStyle(color: _kWarning, fontSize: 11))),
            ]),
          ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _kPrimary))
        else if (_errorMsg != null)
          Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _kOffline.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kOffline.withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: _kOffline, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMsg!,
                    style: TextStyle(color: _kOffline, fontSize: 12))),
              ]),
            ),
            TextButton.icon(
              onPressed: _fetchStatus,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Retry"),
            ),
          ])
        else
          Column(children: [
            _forceRow(Icons.location_on_rounded, const Color(0xFF2563EB),
                "GPS Tracking", _trackOn, (en) async {
              final ok = await widget.controller.forceTracking(
                  userId: u["id"], enabled: en);
              if (ok && mounted) setState(() => _trackOn = en);
            }),
            const SizedBox(height: 10),
            _forceRow(Icons.mic_rounded, const Color(0xFF7C3AED),
                "Voice Recording", _recOn, (en) async {
              final ok = await widget.controller.forceRecording(
                  userId: u["id"], enabled: en);
              if (ok && mounted) setState(() => _recOn = en);
            }),
          ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSec,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text("Close"),
          ),
        ),
      ]),
    );
  }

  Widget _forceRow(IconData icon, Color color, String title,
      bool isOn, Future<void> Function(bool) onToggle) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: _kTextPri, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text(isOn ? "Currently FORCED ON" : "Currently OFF",
                style: TextStyle(
                    color: isOn ? _kOffline : _kTextSec,
                    fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: ElevatedButton(
              onPressed: () => onToggle(!isOn),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOn
                    ? _kOffline.withOpacity(0.1)
                    : color.withOpacity(0.1),
                foregroundColor: isOn ? _kOffline : color,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: isOn
                            ? _kOffline.withOpacity(0.3)
                            : color.withOpacity(0.3))),
              ),
              child: Text(isOn ? "Turn OFF" : "Force ON",
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
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
      if (mounted) setState(() { _recs = r.take(3).toList(); _loading = false; });
    });
  }

  String _fmt(String? ts) {
    if (ts == null || ts.trim().isEmpty) return "—";
    try {
      final normalised = ts.trim().replaceFirst(RegExp(r' (?=\d{2}:\d{2})'), 'T');
      final dt = DateTime.parse(normalised).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}-"
             "${dt.month.toString().padLeft(2, '0')}-${dt.year} "
             "${dt.hour.toString().padLeft(2, '0')}:"
             "${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) { return ts ?? "—"; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(14),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2,
              color: _kPrimary)));
    }
    if (_recs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text("No recordings yet",
            style: const TextStyle(color: _kTextSec, fontSize: 12)),
      );
    }
    return Column(children: _recs.map((r) {
      final dur  = r["duration_seconds"] as int? ?? 0;
      final mins = dur ~/ 60;
      final secs = dur % 60;
      final base         = widget.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final downloadPath = r['download_url'] as String? ?? '';
      final url          = downloadPath.startsWith('http')
          ? downloadPath : '$base$downloadPath';
      final token = GetStorage().read("token") ?? "";

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder)),
        child: Row(children: [
          const Icon(Icons.audio_file_rounded,
              color: Color(0xFFEA580C), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmt(r["started_at"]),
                style: const TextStyle(color: _kTextSec, fontSize: 11)),
            if (dur > 0)
              Text("$mins:${secs.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                      color: Color(0xFFEA580C), fontSize: 11,
                      fontWeight: FontWeight.w700)),
          ])),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.play_circle_rounded,
                color: Color(0xFFEA580C), size: 26),
            onPressed: () async {
              final player = AudioPlayer();
              final uri = Uri.parse(url).replace(
                  queryParameters: {'token': token});
              try {
                await player.setUrl(uri.toString());
                await player.play();
              } catch (e) {
                Get.snackbar("Playback Error", "Could not play: $e",
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
          ),
        ]),
      );
    }).toList());
  }
}