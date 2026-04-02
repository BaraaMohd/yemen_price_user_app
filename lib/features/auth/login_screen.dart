import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/service_locator.dart';
import '../products/screens/merchant_store_screen.dart';
import 'signup_screen.dart';
import '../ministry/screens/ministry_dashboard_screen.dart';
import '../../../core/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscured = true;

  Future<void> _login() async {
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showSnack(context.tr("يرجى ملء جميع الحقول"), Colors.orange);
      return;
    }

    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    if (!online) {
      _showSnack(context.tr("لا يوجد اتصال بالإنترنت لتسجيل الدخول"), Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await locator<Dio>().post(
        AppConfig.loginEndpoint,
        data: FormData.fromMap({
          "phone": phone,
          "password": password,
        }),
      );

      if (!mounted) return;

      if (response.data['status'] == 'success') {
        final userData = response.data['user'];
        await AuthSession.saveFromUser(userData);

        if (!mounted) return;

        _showSnack(context.tr("مرحباً بك في بوابة التاجر 🤝"), Colors.green);
        final role = (userData['role'] ?? 'merchant').toString().toLowerCase();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => role == 'ministry'
                ? const MinistryDashboardScreen()
                : const MerchantStoreScreen(),
          ),
        );
      } else {
        _showSnack(
          response.data['message'] ?? context.tr("بيانات الدخول خاطئة"),
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr("تعذر الاتصال بخوادم الوزارة 🌐"), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr("دخول بوابة التاجر")),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: theme.shadowColor.withValues(alpha: 0.08), blurRadius: 26, offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)]),
                        ),
                        child: const Icon(Icons.security_rounded, size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      Text(context.tr("نظام مراقبة الأسعار"), textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 24)),
                      const SizedBox(height: 26),
                      _buildInputField(controller: _phoneController, label: context.tr("رقم هاتف المتجر"), icon: Icons.phone_android, isPhone: true),
                      const SizedBox(height: 14),
                      _buildInputField(controller: _passwordController, label: context.tr("كلمة المرور"), icon: Icons.lock_outline, isPass: true),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: theme.colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                          child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)) : Text(context.tr("تأكيد الدخول"), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MerchantSignupScreen())),
                        child: Text(context.tr("متجر جديد؟ انضم للمنظومة الآن وسجل موقعك"), textAlign: TextAlign.center, style: GoogleFonts.cairo(color: theme.primaryColor, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, bool isPass = false, bool isPhone = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass ? _isObscured : false,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
        prefixIcon: isPass ? IconButton(icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscured = !_isObscured)) : null,
        suffixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
      ),
    );
  }
}
