import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/login_controller.dart';

class LoginPage extends StatelessWidget {
  final LoginController c = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 600;
    final isMedium = size.width >= 600 && size.width < 900;

    final double hPad = isSmall ? 20 : (isMedium ? 32 : 48);
    final double cardPad = isSmall ? 24 : (isMedium ? 36 : 48);
    final double maxW = isSmall ? 400 : (isMedium ? 480 : 520);
    final double titleSize = isSmall ? 28 : (isMedium ? 32 : 36);
    final double logoSize = isSmall ? 75 : 85;
    final double logoIconSize = isSmall ? 40 : 48;

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
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.blueGrey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPad),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo ──────────────────────────────
                          Container(
                            height: logoSize,
                            width: logoSize,
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
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: logoIconSize,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Title ─────────────────────────────
                          Text(
                            "E-Tracker",
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Employee Location Management",
                            style: TextStyle(
                              fontSize: isSmall ? 13 : 15,
                              color: Colors.blueGrey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmall ? 32 : 40),

                          // ── Username ──────────────────────────
                          _InputField(
                            label: "Username",
                            icon: Icons.person_outline,
                            onChanged: (v) {
                              c.username.value = v;
                              c.clearError();
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Password ──────────────────────────
                          Obx(() => _InputField(
                                label: "Password",
                                icon: Icons.lock_outline,
                                obscure: c.obscurePassword.value,
                                onChanged: (v) {
                                  c.password.value = v;
                                  c.clearError();
                                },
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    c.obscurePassword.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.blueGrey[600],
                                  ),
                                  onPressed: c.togglePasswordVisibility,
                                ),
                              )),
                          const SizedBox(height: 16),

                          // ── Inline Error Message ──────────────
                          Obx(() {
                            if (c.errorMessage.value.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red[200]!, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red[700], size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.errorMessage.value,
                                      style: TextStyle(
                                        color: Colors.red[800],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // ── Login Button ──────────────────────
                          Obx(() => SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed:
                                      c.loading.value ? null : c.login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor:
                                        Colors.blueGrey.withOpacity(0.4),
                                    disabledBackgroundColor:
                                        Colors.blueGrey[300],
                                  ),
                                  child: c.loading.value
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Login",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                ),
                              )),
                          const SizedBox(height: 28),

                          // ── Features Info ─────────────────────
                          _FeaturesCard(isSmall: isSmall),
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
}

// ── Reusable input field ──────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  final ValueChanged<String> onChanged;
  final Widget? suffixIcon;

  const _InputField({
    required this.label,
    required this.icon,
    required this.onChanged,
    this.obscure = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        prefixIcon: Icon(icon, color: Colors.blueGrey[600]),
        suffixIcon: suffixIcon,
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
        filled: true,
        fillColor: Colors.blueGrey[50],
      ),
    );
  }
}

// ── Features card ─────────────────────────────────────────────────────────────

class _FeaturesCard extends StatelessWidget {
  final bool isSmall;

  const _FeaturesCard({required this.isSmall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _FeatureRow(Icons.my_location, "Live Location Tracking", isSmall),
          const SizedBox(height: 10),
          _FeatureRow(Icons.fence, "Geofence Management", isSmall),
          const SizedBox(height: 10),
          _FeatureRow(
              Icons.notifications_active, "Real-time Notifications", isSmall),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isSmall;

  const _FeatureRow(this.icon, this.text, this.isSmall);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: isSmall ? 18 : 20, color: Colors.blueGrey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmall ? 13 : 14,
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}