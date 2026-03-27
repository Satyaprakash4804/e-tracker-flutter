import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:get_storage/get_storage.dart';
import '../../routes/app_routes.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_endpoints.dart';

class EmployeeRegistrationPage extends StatefulWidget {
  const EmployeeRegistrationPage({super.key});

  @override
  State<EmployeeRegistrationPage> createState() =>
      _EmployeeRegistrationPageState();
}

class _EmployeeRegistrationPageState extends State<EmployeeRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final fullName = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final emergencyContact = TextEditingController();
  final emergencyName = TextEditingController();

  String gender = "Male";
  String? state;
  bool agree = false;
  bool isLoading = false;

  File? selfie;
  File? aadhar;

  final picker = ImagePicker();

  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
    "Delhi", "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand",
    "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
    "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan",
    "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh",
    "Uttarakhand", "West Bengal"
  ];

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    whatsapp.dispose();
    email.dispose();
    address.dispose();
    emergencyContact.dispose();
    emergencyName.dispose();
    super.dispose();
  }

  // Validators
  String? validateName(String? value) {
    if (value == null || value.isEmpty) return "Full name is required";
    if (value.length < 3) return "Name must be at least 3 characters";
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) return "Only letters allowed";
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Phone number is required";
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return "Enter valid 10-digit mobile number";
    return null;
  }

  String? validateWhatsApp(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return "Enter valid 10-digit mobile number";
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Enter valid email address";
    }
    return null;
  }

  Future<void> pickSelfie(ImageSource source) async {
    final XFile? img = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (img != null) {
      setState(() => selfie = File(img.path));
    }
  }

  Future<void> pickAadhar() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() => aadhar = File(file.path));
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        "Validation Error",
        "Please fill all required fields correctly",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    if (selfie == null || aadhar == null) {
      Get.snackbar(
        "Missing Documents",
        "Please upload selfie and Aadhaar document",
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    if (!agree) {
      Get.snackbar(
        "Terms Required",
        "Please accept Terms & Conditions to proceed",
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    setState(() => isLoading = true);

    final box = GetStorage();
    final int userId = box.read("user_id");

    final request = http.MultipartRequest(
      "POST",
      Uri.parse(ApiEndpoints.employeeRegister),
    );

    request.fields.addAll({
      "user_id": userId.toString(),
      "full_name": fullName.text.trim(),
      "phone": phone.text.trim(),
      "whatsapp": whatsapp.text.trim().isEmpty ? phone.text.trim() : whatsapp.text.trim(),
      "email": email.text.trim(),
      "gender": gender,
      "state": state!,
      "address": address.text.trim(),
      "emergency_contact": emergencyContact.text.trim(),
      "emergency_name": emergencyName.text.trim(),
    });

    request.files.add(await http.MultipartFile.fromPath("selfie", selfie!.path));
    request.files.add(await http.MultipartFile.fromPath("aadhar", aadhar!.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        box.write("employee_registered", true);
        final dest = box.read("post_registration_route") ?? Routes.EMPLOYEE_DASHBOARD;
        box.remove("post_registration_route"); // clean up
        Get.offAllNamed(dest);        
        Get.snackbar(
          "Success",
          "Registration completed successfully!",
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
        );
      } else {
        Get.snackbar(
          "Registration Failed",
          "Unable to complete registration. Please try again.",
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
        );
        print(responseBody);
      }
    } catch (e) {
      print("❌ ERROR: $e");
      Get.snackbar(
        "Network Error",
        "Please check your internet connection",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      setState(() => isLoading = false);
    }
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
                            onPressed: () {
                              // Clear session and go back to login
                              final box = GetStorage();
                              box.remove("logged_in");
                              box.remove("role");
                              box.remove("username");
                              box.remove("user_id");
                              Get.offAllNamed(Routes.LOGIN);
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Employee Registration",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : (isMediumScreen ? 24 : 26),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Join our workforce tracking system",
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
                    // Info Cards
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _headerFeature(Icons.shield_outlined, "Secure", isSmallScreen),
                          _headerFeature(Icons.access_time, "Real-time", isSmallScreen),
                          _headerFeature(Icons.verified_user, "Verified", isSmallScreen),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : (isMediumScreen ? 32 : 48),
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLargeScreen ? 900 : double.infinity,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle("Personal Information", isSmallScreen),
                            SizedBox(height: 12),
                            _buildTextField(
                              controller: fullName,
                              label: "Full Name",
                              icon: Icons.person_outline,
                              validator: validateName,
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: phone,
                              label: "Mobile Number",
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: validatePhone,
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: whatsapp,
                              label: "WhatsApp Number (Optional)",
                              icon: Icons.chat_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: validateWhatsApp,
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: email,
                              label: "Email Address",
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: validateEmail,
                            ),
                            SizedBox(height: 24),

                            _sectionTitle("Gender", isSmallScreen),
                            SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blueGrey[200]!),
                              ),
                              child: Row(
                                children: ["Male", "Female", "Other"].map((g) {
                                  return Expanded(
                                    child: RadioListTile<String>(
                                      value: g,
                                      groupValue: gender,
                                      onChanged: (v) => setState(() => gender = v!),
                                      title: Text(
                                        g,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 13 : 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blueGrey[800],
                                        ),
                                      ),
                                      activeColor: Colors.blueGrey[700],
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(height: 24),

                            _sectionTitle("Location Details", isSmallScreen),
                            SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration("Select State", Icons.location_on_outlined),
                              items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => state = v),
                              validator: (v) => v == null ? "Please select your state" : null,
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: address,
                              label: "Full Address",
                              icon: Icons.home_outlined,
                              maxLines: 3,
                              validator: (v) => v!.isEmpty ? "Address is required" : null,
                            ),
                            SizedBox(height: 24),

                            _sectionTitle("Emergency Contact", isSmallScreen),
                            SizedBox(height: 12),
                            _buildTextField(
                              controller: emergencyName,
                              label: "Emergency Contact Name",
                              icon: Icons.contact_emergency_outlined,
                              validator: (v) => v!.isEmpty ? "Emergency contact name required" : null,
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: emergencyContact,
                              label: "Emergency Contact Number",
                              icon: Icons.phone_in_talk_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: validatePhone,
                            ),
                            SizedBox(height: 28),

                            _sectionTitle("Document Upload", isSmallScreen),
                            SizedBox(height: 12),
                            _fileUploadCard(
                              title: "Profile Selfie",
                              subtitle: "Clear photo with face visible",
                              file: selfie,
                              icon: Icons.camera_alt_outlined,
                              onCamera: () => pickSelfie(ImageSource.camera),
                              onGallery: () => pickSelfie(ImageSource.gallery),
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: 16),

                            _fileUploadCard(
                              title: "Aadhaar Document",
                              subtitle: "PDF or image format (Front & Back)",
                              file: aadhar,
                              icon: Icons.badge_outlined,
                              onPick: pickAadhar,
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: 28),

                            // Terms & Conditions
                            Container(
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
                              child: CheckboxListTile(
                                value: agree,
                                onChanged: (v) => setState(() => agree = v!),
                                activeColor: Colors.blueGrey[700],
                                title: Text(
                                  "I agree to Terms & Conditions and Privacy Policy",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    "Real-time location tracking enabled during work hours",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: Colors.blueGrey[600],
                                    ),
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            ),
                            SizedBox(height: 28),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : submit,
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
                                child: isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        "Complete Registration",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 20),

                            // Footer Info
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "Powered by E-Tracker IT Solutions",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      color: Colors.blueGrey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Secure • Real-time • Reliable",
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerFeature(IconData icon, String label, bool isSmallScreen) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: isSmallScreen ? 20 : 24),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 16 : 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[800],
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blueGrey[700]),
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

  Widget _fileUploadCard({
    required String title,
    required String subtitle,
    required File? file,
    required IconData icon,
    VoidCallback? onCamera,
    VoidCallback? onGallery,
    VoidCallback? onPick,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: file != null ? Colors.green[300]! : Colors.blueGrey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueGrey[100]!,
                      Colors.blueGrey[200]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blueGrey[700], size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 15 : 16,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (file != null)
                Icon(Icons.check_circle, color: Colors.green, size: 28),
            ],
          ),
          if (file != null) ...[
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.green[700], size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onCamera != null)
                OutlinedButton.icon(
                  icon: Icon(Icons.camera_alt, size: 18),
                  label: Text("Camera"),
                  onPressed: onCamera,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey[700],
                    side: BorderSide(color: Colors.blueGrey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              if (onGallery != null)
                OutlinedButton.icon(
                  icon: Icon(Icons.photo_library, size: 18),
                  label: Text("Gallery"),
                  onPressed: onGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey[700],
                    side: BorderSide(color: Colors.blueGrey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              if (onPick != null)
                OutlinedButton.icon(
                  icon: Icon(Icons.upload_file, size: 18),
                  label: Text("Upload"),
                  onPressed: onPick,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey[700],
                    side: BorderSide(color: Colors.blueGrey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}