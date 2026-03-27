import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

import '../../controllers/employee_controller.dart';
import '../../constants/api_endpoints.dart';
import '../../data/api_service.dart';

class EmployeeProfilePage extends StatelessWidget {
  EmployeeProfilePage({super.key});

  final EmployeeController c = Get.find<EmployeeController>();

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
          child: FutureBuilder(
            future: ApiService.get(
              "${ApiEndpoints.employeeProfile}/${c.userId}",
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.blueGrey[700],
                    strokeWidth: 3,
                  ),
                );
              }

              if (!snapshot.hasData ||
                  snapshot.data == null ||
                  snapshot.data["success"] != true) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.blueGrey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Failed to load profile",
                        style: TextStyle(
                          color: Colors.blueGrey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data["data"];

              return CustomScrollView(
                slivers: [
                  // Enhanced Hero Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blueGrey[700]!,
                            Colors.blueGrey[600]!,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Back Button Row
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => Get.back(),
                                ),
                                Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                          
                          // Profile Image and Name
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: isSmallScreen ? 20 : 32,
                            ),
                            child: Column(
                              children: [
                                // Large Profile Image
                                GestureDetector(
                                  onTap: data["selfie_path"] != null
                                      ? () => _openImageViewer(data['selfie_path'])
                                      : null,

                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 30,
                                              offset: Offset(0, 10),
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 5,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: isSmallScreen ? 70 : 85,
                                            backgroundColor: Colors.white,
                                            backgroundImage: data["selfie_path"] != null
                                                ? NetworkImage(data['selfie_path'])
                                                : null,
                                            
                                            child: data["selfie_path"] == null
                                                ? Icon(
                                                    Icons.person,
                                                    size: isSmallScreen ? 70 : 85,
                                                    color: Colors.blueGrey[300],
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      // Zoom icon overlay
                                      if (data["selfie_path"] != null)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.zoom_in,
                                              color: Colors.blueGrey[700],
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 20),
                                
                                // Name
                                Text(
                                  data["full_name"] ?? data["username"] ?? "Employee",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 26 : 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                SizedBox(height: 8),
                                
                                // Username
                                Text(
                                  "@${data["username"] ?? "employee"}",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 17,
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Verified Badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Verified Employee",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : (isMediumScreen ? 24 : 32),
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isLargeScreen ? 1000 : double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              
                              // Quick Stats Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _statCard(
                                      icon: Icons.phone_outlined,
                                      label: "Contact",
                                      value: data["phone"] != null ? "Available" : "N/A",
                                      color: Colors.blue,
                                      isSmallScreen: isSmallScreen,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _statCard(
                                      icon: Icons.email_outlined,
                                      label: "Email",
                                      value: data["email"] != null ? "Verified" : "N/A",
                                      color: Colors.green,
                                      isSmallScreen: isSmallScreen,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 32),

                              _sectionTitle("Personal Information", isSmallScreen),
                              SizedBox(height: 16),

                              _infoCard(
                                icon: Icons.person_outline,
                                label: "Username",
                                value: data["username"],
                                isSmallScreen: isSmallScreen,
                              ),
                              _infoCard(
                                icon: Icons.badge_outlined,
                                label: "Full Name",
                                value: data["full_name"],
                                isSmallScreen: isSmallScreen,
                              ),
                              _infoCard(
                                icon: Icons.phone_outlined,
                                label: "Phone",
                                value: data["phone"],
                                isSmallScreen: isSmallScreen,
                              ),
                              _infoCard(
                                icon: Icons.email_outlined,
                                label: "Email",
                                value: data["email"],
                                isSmallScreen: isSmallScreen,
                              ),
                              _infoCard(
                                icon: Icons.location_on_outlined,
                                label: "State",
                                value: data["state"],
                                isSmallScreen: isSmallScreen,
                              ),
                              _infoCard(
                                icon: Icons.home_outlined,
                                label: "Address",
                                value: data["address"],
                                maxLines: 3,
                                isSmallScreen: isSmallScreen,
                              ),

                              SizedBox(height: 32),

                              // Documents Section
                              _sectionTitle("Documents", isSmallScreen),
                              SizedBox(height: 16),

                              if (data["aadhar_path"] != null)
                                _documentTile(
                                  title: "Aadhaar Card",
                                  url: data['aadhar_path'],
                                  isSmallScreen: isSmallScreen,
                                )
                              else
                                _emptyState(
                                  icon: Icons.description_outlined,
                                  message: "No documents uploaded",
                                  isSmallScreen: isSmallScreen,
                                ),

                              SizedBox(height: 32),

                              // Uploads Section
                              _sectionTitle("My Uploads", isSmallScreen),
                              SizedBox(height: 16),

                              FutureBuilder(
                                future: ApiService.get(
                                  "${ApiEndpoints.employeeUploads}/${c.userId}",
                                ),
                                builder: (_, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: CircularProgressIndicator(
                                          color: Colors.blueGrey[700],
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  }

                                  if (!snap.hasData ||
                                      snap.data == null ||
                                      snap.data["success"] != true) {
                                    return _emptyState(
                                      icon: Icons.cloud_upload_outlined,
                                      message: "No uploads found",
                                      isSmallScreen: isSmallScreen,
                                    );
                                  }

                                  final List uploads = snap.data["uploads"] ?? [];

                                  if (uploads.isEmpty) {
                                    return _emptyState(
                                      icon: Icons.cloud_upload_outlined,
                                      message: "No uploads yet",
                                      isSmallScreen: isSmallScreen,
                                    );
                                  }

                                  return Column(
                                    children: uploads.map((u) {
                                      final imgUrl = u['image_path'];


                                      return Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blueGrey.withOpacity(0.12),
                                              blurRadius: 12,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.all(16),
                                          leading: GestureDetector(
                                            onTap: () => _openImageViewer(imgUrl),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.blueGrey.withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  imgUrl,
                                                  width: isSmallScreen ? 70 : 80,
                                                  height: isSmallScreen ? 70 : 80,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: isSmallScreen ? 70 : 80,
                                                    height: isSmallScreen ? 70 : 80,
                                                    color: Colors.blueGrey[100],
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.blueGrey[400],
                                                      size: 30,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            u["description"] ?? "Upload",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 15 : 16,
                                              color: Colors.blueGrey[900],
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.battery_charging_full,
                                                      size: 16,
                                                      color: Colors.green[600],
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      "${u['battery']}%",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blueGrey[700],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 16,
                                                      color: Colors.blueGrey[600],
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      u['uploaded_at'],
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blueGrey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.visibility_outlined,
                                              color: Colors.blueGrey[700],
                                              size: 22,
                                            ),
                                          ),
                                          onTap: () => _openImageViewer(imgUrl),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isSmallScreen) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isSmallScreen ? 20 : 22,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey[900],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String? value,
    int maxLines = 1,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blueGrey[700],
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  value ?? "—",
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile({
    required String title,
    required String url,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 18),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.description,
            color: Colors.orange[700],
            size: 28,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 15 : 16,
            color: Colors.blueGrey[900],
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            "Tap to view document",
            style: TextStyle(
              fontSize: 13,
              color: Colors.blueGrey[600],
            ),
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.open_in_new,
            color: Colors.blueGrey[700],
            size: 22,
          ),
        ),
        onTap: () => _openImageViewer(url),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String message,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 40 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isSmallScreen ? 48 : 56,
                color: Colors.blueGrey[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.blueGrey[600],
                fontSize: isSmallScreen ? 14 : 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openImageViewer(String url) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: PhotoView(
          imageProvider: NetworkImage(url),
          backgroundDecoration: BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}