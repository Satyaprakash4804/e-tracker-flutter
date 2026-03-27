import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class AdminEmployeeProfilePage extends StatefulWidget {
  const AdminEmployeeProfilePage({super.key});

  @override
  State<AdminEmployeeProfilePage> createState() =>
      _AdminEmployeeProfilePageState();
}

class _AdminEmployeeProfilePageState
    extends State<AdminEmployeeProfilePage> {
  late final int userId;

  final RxBool loading   = true.obs;
  final RxBool isEditing = false.obs;
  final RxMap<String, dynamic> profile = <String, dynamic>{}.obs;
  final RxList uploads = [].obs;

  final fullName = TextEditingController();
  final phone    = TextEditingController();
  final whatsapp = TextEditingController();
  final email    = TextEditingController();
  final address  = TextEditingController();

  String? state;

  // ── Indian states list ────────────────────────────────────────
  static const _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
    'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
    'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Chandigarh', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    userId = Get.arguments as int;
    loadAll();
  }

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    whatsapp.dispose();
    email.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    loading.value = true;
    await loadProfile();
    await loadUploads();
    loading.value = false;
  }

  Future<void> loadProfile() async {
    final res = await ApiService.get(
        "${ApiEndpoints.adminEmployeeProfile}/$userId");
    if (res == null) return;
    final data =
        res is Map && res.containsKey("data") ? res["data"] : res;
    if (data == null) return;
    profile.assignAll(Map<String, dynamic>.from(data));
    fullName.text = profile["full_name"] ?? "";
    phone.text    = profile["phone"]     ?? "";
    whatsapp.text = profile["whatsapp"]  ?? "";
    email.text    = profile["email"]     ?? "";
    address.text  = profile["address"]   ?? "";
    state         = profile["state"];
  }

  Future<void> loadUploads() async {
    final res = await ApiService.get(
        "${ApiEndpoints.adminEmployeeUploads}/$userId");
    if (res == null) return;
    uploads.assignAll(
        res is Map && res.containsKey("data") ? res["data"] : res);
  }

  Future<void> saveProfile() async {
    final res = await ApiService.post(
      "${ApiEndpoints.adminUpdateEmployee}/$userId",
      {
        "full_name": fullName.text.trim(),
        "phone":     phone.text.trim(),
        "whatsapp":  whatsapp.text.trim(),
        "email":     email.text.trim(),
        "state":     state,
        "address":   address.text.trim(),
      },
    );
    if (res != null) {
      isEditing.value = false;
      await loadProfile();
      Get.snackbar("Success", "Profile updated successfully",
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    } else {
      Get.snackbar("Error", "Failed to update profile",
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    }
  }

  Future<void> deleteUpload(int uploadId) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Upload",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900])),
        content: Text(
            "Are you sure you want to delete this photo?",
            style: TextStyle(color: Colors.blueGrey[700])),
        actions: [
          // ✅ FIXED
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text("Cancel",
                style: TextStyle(color: Colors.blueGrey[600])),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true), // ✅ FIXED
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

    if (confirm != true) return;

    final res = await ApiService.delete(
        "${ApiEndpoints.adminDeleteUpload}/$uploadId");

    if (res != null) {
      uploads.removeWhere((e) => e["id"] == uploadId);
      Get.snackbar("Success", "Photo deleted successfully",
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    } else {
      Get.snackbar("Error", "Failed to delete photo",
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    }
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final w      = size.width;
    final isSmall  = w < 600;
    final isMedium = w >= 600 && w < 900;
    final isLarge  = w >= 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey[50]!, Colors.blueGrey[100]!],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            if (loading.value) {
              return Center(
                child: CircularProgressIndicator(
                    color: Colors.blueGrey[700], strokeWidth: 3),
              );
            }
            if (profile.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.blueGrey[400]),
                    const SizedBox(height: 16),
                    Text("Profile not available",
                        style: TextStyle(
                            color: Colors.blueGrey[600], fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: loadAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              );
            }

            final selfie = profile["selfie_path"];
            final aadhar = profile["aadhar_path"];

            return CustomScrollView(
              slivers: [
                // ── Hero section ──
                SliverToBoxAdapter(
                  child: _heroSection(selfie, isSmall, isMedium, isLarge),
                ),

                // ── Content ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 14 : (isMedium ? 24 : 40),
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isLarge ? 800 : double.infinity),
                        child: isLarge
                            // Large: 2-column layout
                            ? _largeLayout(aadhar, isSmall, isLarge)
                            // Small/Medium: single column
                            : _singleColumn(aadhar, isSmall),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Large screen 2-column layout ─────────────────────────────
  Widget _largeLayout(dynamic aadhar, bool isSmall, bool isLarge) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle("Personal Information", false),
            const SizedBox(height: 16),
            Obx(() => isEditing.value
                ? _editFields(false)
                : _infoFields(false)),
          ]),
        ),
        const SizedBox(width: 24),
        // Right column
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle("Documents", false),
            const SizedBox(height: 16),
            if (aadhar != null)
              _documentTile(title: "Aadhaar Card", url: aadhar, isSmall: false)
            else
              _emptyState(
                  icon: Icons.description_outlined,
                  message: "No documents uploaded",
                  isSmall: false),
            const SizedBox(height: 28),
            _sectionTitle("Uploaded Photos", false),
            const SizedBox(height: 16),
            Obx(() => _uploadsList(false)),
          ]),
        ),
      ],
    );
  }

  // ── Single-column layout ─────────────────────────────────────
  Widget _singleColumn(dynamic aadhar, bool isSmall) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle("Personal Information", isSmall),
      const SizedBox(height: 16),
      Obx(() => isEditing.value
          ? _editFields(isSmall)
          : _infoFields(isSmall)),
      const SizedBox(height: 28),
      _sectionTitle("Documents", isSmall),
      const SizedBox(height: 16),
      if (aadhar != null)
        _documentTile(title: "Aadhaar Card", url: aadhar, isSmall: isSmall)
      else
        _emptyState(
            icon: Icons.description_outlined,
            message: "No documents uploaded",
            isSmall: isSmall),
      const SizedBox(height: 28),
      _sectionTitle("Uploaded Photos", isSmall),
      const SizedBox(height: 16),
      Obx(() => _uploadsList(isSmall)),
    ]);
  }

  // ================================================================
  // HERO SECTION
  // ================================================================
  Widget _heroSection(
      dynamic selfie, bool isSmall, bool isMedium, bool isLarge) {
    final avatarRadius = isSmall ? 60.0 : (isMedium ? 72.0 : 80.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey[700]!, Colors.blueGrey[600]!],
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10))],
      ),
      child: Column(children: [
        // ── Top bar ──
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: isSmall ? 8 : 12),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                // ✅ FIXED
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                onPressed: () => Get.back(),
                padding: const EdgeInsets.all(10),
              ),
            ),
            const Spacer(),
            Obx(() => isEditing.value
                ? Row(children: [
                    _headerBtn("Cancel", Icons.close, () {
                      isEditing.value = false;
                      loadProfile();
                    }),
                    const SizedBox(width: 8),
                    _headerBtn("Save", Icons.check, saveProfile,
                        filled: true),
                  ])
                : _headerBtn("Edit", Icons.edit_outlined,
                    () => isEditing.value = true)),
          ]),
        ),

        // ── Avatar + name ──
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isSmall ? 16 : 24),
          child: isLarge
              // side-by-side on large
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _avatar(selfie, avatarRadius),
                    const SizedBox(width: 32),
                    _nameBlock(isSmall),
                  ],
                )
              // stacked on small/medium
              : Column(children: [
                  _avatar(selfie, avatarRadius),
                  const SizedBox(height: 16),
                  _nameBlock(isSmall),
                ]),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _headerBtn(String label, IconData icon, VoidCallback onTap,
      {bool filled = false}) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blueGrey[700],
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: TextButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }

  Widget _avatar(dynamic selfie, double radius) {
    return GestureDetector(
      onTap: selfie != null
          ? () => _openFullScreenImage(selfie, "Profile Photo")
          : null,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 2)],
          ),
          child: Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4)),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white,
              backgroundImage:
                  selfie != null ? NetworkImage(selfie) : null,
              child: selfie == null
                  ? Icon(Icons.person,
                      size: radius, color: Colors.blueGrey[300])
                  : null,
            ),
          ),
        ),
        if (selfie != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6)],
              ),
              child: Icon(Icons.zoom_in,
                  color: Colors.blueGrey[700], size: 16),
            ),
          ),
      ]),
    );
  }

  Widget _nameBlock(bool isSmall) {
    return Column(children: [
      Text(
        profile["full_name"] ?? profile["username"] ?? "Employee",
        style: TextStyle(
            fontSize: isSmall ? 22 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 4)]),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      Text("@${profile["username"] ?? "employee"}",
          style: TextStyle(
              fontSize: isSmall ? 13 : 15,
              color: Colors.white.withOpacity(0.9))),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildVerificationBadge(),
          _heroPill(Icons.admin_panel_settings, "Admin View",
              Colors.white.withOpacity(0.15)),
        ],
      ),
    ]);
  }

  Widget _heroPill(IconData icon, String label, Color bg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  // ================================================================
  // INFO FIELDS (read mode)
  // ================================================================
  Widget _infoFields(bool isSmall) {
    final fields = [
      {'icon': Icons.person_outline, 'label': 'Username', 'key': 'username'},
      {'icon': Icons.badge_outlined,  'label': 'Full Name', 'key': 'full_name'},
      {'icon': Icons.phone_outlined,  'label': 'Phone',     'key': 'phone'},
      {'icon': Icons.phone_android_outlined, 'label': 'WhatsApp', 'key': 'whatsapp'},
      {'icon': Icons.email_outlined,  'label': 'Email',     'key': 'email'},
      {'icon': Icons.location_on_outlined, 'label': 'State', 'key': 'state'},
      {'icon': Icons.home_outlined,   'label': 'Address',   'key': 'address'},
    ];
    return Column(
      children: fields.map((f) => _infoCard(
        icon: f['icon'] as IconData,
        label: f['label'] as String,
        value: profile[f['key']],
        isSmall: isSmall,
        maxLines: f['key'] == 'address' ? 3 : 1,
      )).toList(),
    );
  }

  // ================================================================
  // EDIT FIELDS (edit mode)
  // ================================================================
  Widget _editFields(bool isSmall) {
    return Column(children: [
      _editableField(
          icon: Icons.badge_outlined,
          label: "Full Name",
          controller: fullName,
          isSmall: isSmall),
      _editableField(
          icon: Icons.phone_outlined,
          label: "Phone",
          controller: phone,
          keyboardType: TextInputType.phone,
          isSmall: isSmall),
      _editableField(
          icon: Icons.phone_android_outlined,
          label: "WhatsApp",
          controller: whatsapp,
          keyboardType: TextInputType.phone,
          isSmall: isSmall),
      _editableField(
          icon: Icons.email_outlined,
          label: "Email",
          controller: email,
          keyboardType: TextInputType.emailAddress,
          isSmall: isSmall),
      // State dropdown
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.location_on_outlined,
                color: Colors.blueGrey[700], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _states.contains(state) ? state : null,
              decoration: InputDecoration(
                labelText: "State",
                labelStyle: TextStyle(color: Colors.blueGrey[600]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              isExpanded: true,
              items: _states
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => state = v),
            ),
          ),
        ]),
      ),
      _editableField(
          icon: Icons.home_outlined,
          label: "Address",
          controller: address,
          maxLines: 3,
          isSmall: isSmall),
    ]);
  }

  // ================================================================
  // UPLOADS LIST
  // ================================================================
  Widget _uploadsList(bool isSmall) {
    if (uploads.isEmpty) {
      return _emptyState(
          icon: Icons.cloud_upload_outlined,
          message: "No uploads yet",
          isSmall: isSmall);
    }
    return Column(
      children: uploads.map<Widget>((u) {
        final imgUrl = u['image_path'];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.blueGrey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            // Image
            GestureDetector(
              onTap: () =>
                  _openFullScreenImage(imgUrl, "Uploaded Photo"),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: Image.network(
                  imgUrl,
                  height: isSmall ? 180 : 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: isSmall ? 180 : 240,
                    color: Colors.blueGrey[100],
                    child: Icon(Icons.broken_image,
                        color: Colors.blueGrey[400], size: 50),
                  ),
                ),
              ),
            ),
            // Meta
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _metaRow(Icons.access_time,
                    u['uploaded_at'] ?? "Unknown",
                    Colors.blueGrey[600]!),
                const SizedBox(height: 6),
                _metaRow(Icons.location_on_outlined,
                    "${u['latitude']}, ${u['longitude']}",
                    Colors.blueGrey[600]!),
                const SizedBox(height: 6),
                _metaRow(Icons.battery_charging_full,
                    "${u['battery']}%",
                    Colors.green[600]!),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    // ✅ properly calling deleteUpload
                    onPressed: () => deleteUpload(u["id"]),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text("Delete Photo"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _metaRow(IconData icon, String text, Color iconColor) =>
      Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: Colors.blueGrey[700]),
              overflow: TextOverflow.ellipsis),
        ),
      ]);

  // ================================================================
  // SHARED WIDGETS
  // ================================================================
  Widget _sectionTitle(String title, bool isSmall) => Text(
        title,
        style: TextStyle(
            fontSize: isSmall ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[900],
            letterSpacing: 0.3),
      );

  Widget _infoCard({
    required IconData icon,
    required String label,
    required dynamic value,
    int maxLines = 1,
    required bool isSmall,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.blueGrey[700], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text(
                    value?.toString().isNotEmpty == true
                        ? value.toString()
                        : "—",
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: isSmall ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[900]),
                  ),
                ]),
          ),
        ]),
      );

  Widget _editableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    required bool isSmall,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.blueGrey[700], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[900]),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                    color: Colors.blueGrey[500], fontSize: 12),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ]),
      );

  Widget _documentTile({
    required String title,
    required String url,
    required bool isSmall,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(isSmall ? 14 : 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.description,
                color: Colors.orange[700], size: 26),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmall ? 14 : 15,
                  color: Colors.blueGrey[900])),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("Tap to view document",
                style: TextStyle(
                    fontSize: 12, color: Colors.blueGrey[600])),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.open_in_new,
                color: Colors.blueGrey[700], size: 20),
          ),
          onTap: () => _openFullScreenImage(url, title),
        ),
      );

  Widget _emptyState({
    required IconData icon,
    required String message,
    required bool isSmall,
  }) =>
      Container(
        padding: EdgeInsets.all(isSmall ? 32 : 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.blueGrey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))],
        ),
        child: Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.blueGrey[50], shape: BoxShape.circle),
              child: Icon(icon,
                  size: isSmall ? 44 : 52, color: Colors.blueGrey[400]),
            ),
            const SizedBox(height: 14),
            Text(message,
                style: TextStyle(
                    color: Colors.blueGrey[600],
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  // ================================================================
  // FULL SCREEN IMAGE VIEWER
  // ================================================================
  void _openFullScreenImage(String url, String title) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title:
              Text(title, style: const TextStyle(color: Colors.white)),
          // ✅ back button works via default AppBar back
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 100),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // VERIFICATION BADGE
  // ================================================================
  Widget _buildVerificationBadge() {
    final verified = _isProfileComplete();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.2)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: verified
                ? Colors.green.withOpacity(0.5)
                : Colors.orange.withOpacity(0.5),
            width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            verified
                ? Icons.verified
                : Icons.warning_amber_rounded,
            size: 16,
            color: Colors.white),
        const SizedBox(width: 6),
        Text(
          verified ? "Verified" : "Incomplete",
          style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
        ),
      ]),
    );
  }

  bool _isProfileComplete() {
    return profile["full_name"]?.toString().trim().isNotEmpty == true &&
        profile["phone"]?.toString().trim().isNotEmpty    == true &&
        profile["email"]?.toString().trim().isNotEmpty    == true &&
        profile["state"]?.toString().trim().isNotEmpty    == true &&
        profile["address"]?.toString().trim().isNotEmpty  == true &&
        profile["selfie_path"] != null &&
        profile["aadhar_path"] != null;
  }
}