import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/admin_controller.dart';

class AddEmployeePage extends StatefulWidget {
  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final AdminController c = Get.find<AdminController>();
  final _formKey = GlobalKey<FormState>();

  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return "Username is required";
    if (value.length < 4) return "Username must be at least 4 characters";
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return "Only letters, numbers and underscore allowed";
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Password must be at least 6 characters";
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return "Password must contain letters and numbers";
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return "Please confirm password";
    if (value != passwordCtrl.text) return "Passwords do not match";
    return null;
  }

  void handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        "Validation Error",
        "Please fill all fields correctly",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    c.createEmployee(
      usernameCtrl.text.trim(),
      passwordCtrl.text.trim(),
    );
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
              Colors.blueGrey[200]!,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 20 : 24,
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Get.back(),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Add New Employee",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : (isMediumScreen ? 24 : 26),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Create account for workforce tracking",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Info Card
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Employee will receive login credentials via email",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : (isMediumScreen ? 32 : 48),
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isLargeScreen ? 600 : (isMediumScreen ? 550 : double.infinity),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Illustration/Icon
                              Center(
                                child: Container(
                                  height: isSmallScreen ? 100 : 110,
                                  width: isSmallScreen ? 100 : 110,
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
                                    Icons.person_add_rounded,
                                    size: isSmallScreen ? 50 : 56,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 32 : 40),

                              _sectionTitle("Account Credentials", isSmallScreen),
                              SizedBox(height: 16),

                              // Username Field
                              TextFormField(
                                controller: usernameCtrl,
                                decoration: _inputDecoration(
                                  "Username",
                                  Icons.person_outline,
                                  "e.g., john_doe",
                                ),
                                validator: validateUsername,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9_]'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),

                              // Password Field
                              TextFormField(
                                controller: passwordCtrl,
                                obscureText: !showPassword,
                                decoration: _inputDecoration(
                                  "Password",
                                  Icons.lock_outline,
                                  "Min 6 chars, letters & numbers",
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.blueGrey[600],
                                    ),
                                    onPressed: () {
                                      setState(() => showPassword = !showPassword);
                                    },
                                  ),
                                ),
                                validator: validatePassword,
                              ),
                              SizedBox(height: 20),

                              // Confirm Password Field
                              TextFormField(
                                controller: confirmPasswordCtrl,
                                obscureText: !showConfirmPassword,
                                decoration: _inputDecoration(
                                  "Confirm Password",
                                  Icons.lock_reset_outlined,
                                  "Re-enter password",
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.blueGrey[600],
                                    ),
                                    onPressed: () {
                                      setState(() => showConfirmPassword = !showConfirmPassword);
                                    },
                                  ),
                                ),
                                validator: validateConfirmPassword,
                              ),
                              SizedBox(height: 28),

                              // Security Info Card
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.security,
                                            color: Colors.blueGrey[700],
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Security Requirements",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 14 : 15,
                                            color: Colors.blueGrey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 14),
                                    _securityItem("Minimum 6 characters", isSmallScreen),
                                    _securityItem("Contains letters and numbers", isSmallScreen),
                                    _securityItem("Unique username required", isSmallScreen),
                                  ],
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 32 : 40),

                              // Create Button
                              Obx(
                                () => SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: c.loadingCreate.value
                                        ? null
                                        : handleSubmit,
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
                                    child: c.loadingCreate.value
                                        ? SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person_add, size: 20),
                                              SizedBox(width: 10),
                                              Text(
                                                "Create Employee Account",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 14),

                              // Cancel Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () => Get.back(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey[700],
                                    side: BorderSide(
                                      color: Colors.blueGrey[400]!,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 28),

                              // Footer Info
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.blueGrey[600],
                                        size: 28,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Admin Portal",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 14,
                                        color: Colors.blueGrey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "E-Tracker Workforce Management",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        color: Colors.blueGrey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isSmallScreen) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isSmallScreen ? 16 : 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey[800],
        letterSpacing: 0.3,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blueGrey[700]),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.blueGrey[400]),
      prefixIcon: Icon(icon, color: Colors.blueGrey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blueGrey[200]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blueGrey[600]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.blueGrey[50],
    );
  }

  Widget _securityItem(String text, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.blueGrey[700],
          ),
          SizedBox(width: 10),
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
      ),
    );
  }
}