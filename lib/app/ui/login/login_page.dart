import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/login_controller.dart';

class LoginPage extends StatelessWidget {
  final LoginController c = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueGrey[50]!,
              Colors.blueGrey[100]!,
              Colors.blueGrey[200]!,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : (isMediumScreen ? 32 : 48),
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? 400 : (isMediumScreen ? 480 : 520),
                  ),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.blueGrey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isSmallScreen ? 24 : (isMediumScreen ? 36 : 48),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo/Icon
                          Container(
                            height: isSmallScreen ? 75 : 85,
                            width: isSmallScreen ? 75 : 85,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blueGrey[300]!,
                                  Colors.blueGrey[500]!,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: isSmallScreen ? 40 : 48,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 24),

                          // Title
                          Text(
                            "E-Tracker",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 28 : (isMediumScreen ? 32 : 36),
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Employee Location Management",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              color: Colors.blueGrey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 32 : 40),

                          // Username Field
                          TextField(
                            decoration: InputDecoration(
                              labelText: "Username",
                              labelStyle: TextStyle(color: Colors.blueGrey[700]),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Colors.blueGrey[600],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.blueGrey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.blueGrey[600]!,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.blueGrey[50],
                            ),
                            onChanged: (v) => c.username.value = v,
                          ),
                          SizedBox(height: 20),

                          // Password Field
                          Obx(
                            () => TextField(
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: TextStyle(color: Colors.blueGrey[700]),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.blueGrey[600],
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    c.obscurePassword.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.blueGrey[600],
                                  ),
                                  onPressed: () => c.togglePasswordVisibility(),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey[200]!,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey[600]!,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.blueGrey[50],
                              ),
                              obscureText: c.obscurePassword.value,
                              onChanged: (v) => c.password.value = v,
                            ),
                          ),
                          SizedBox(height: 28),

                          // Login Button
                          Obx(
                            () => SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: c.loading.value ? null : () => c.login(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  shadowColor: Colors.blueGrey.withOpacity(0.4),
                                  disabledBackgroundColor: Colors.blueGrey[300],
                                ),
                                child: c.loading.value
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        "Login",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(height: 28),

                          // Features Info
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blueGrey[200]!,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildFeatureRow(
                                  Icons.my_location,
                                  "Live Location Tracking",
                                  isSmallScreen,
                                ),
                                SizedBox(height: 10),
                                _buildFeatureRow(
                                  Icons.fence,
                                  "Geofence Management",
                                  isSmallScreen,
                                ),
                                SizedBox(height: 10),
                                _buildFeatureRow(
                                  Icons.notifications_active,
                                  "Real-time Notifications",
                                  isSmallScreen,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 18 : 20,
            color: Colors.blueGrey[700],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}